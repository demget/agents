# Echo Cleanup: Use the Framework, Remove the Plumbing

Audit this Echo service and remove the code that rebuilds what Echo already provides: error helpers, status guessing, hand-rolled binding, hand-rolled timeouts and request logging, and tests that bypass the router.

The goal is a service an experienced Echo engineer would recognise at a glance:

- handlers that return errors
- one error handler that decides status, logs and writes the body
- middleware that hands errors to that handler instead of guessing
- request DTOs bound once, validated once, mapped explicitly
- `*echo.Context` used inside the request and nowhere else
- tests that go through the router

The primary rule is:

> **Handlers return errors; one error handler turns them into responses.**

Everything in this file is checked against Echo **v5.4.0** source (`github.com/labstack/echo/v5`). Rules about Go in general (interfaces, `any`, wrappers, nil guards) live in the `deslop-go` skill; this file covers what is specific to Echo.

---

# 0. Confirm Echo v5 and its patch level

Read `go.mod`. This file applies only to `github.com/labstack/echo/v5`; on `/v4` its signatures and behaviours are wrong, so stop.

v5 in one paragraph: `Context` is a struct and handlers take `*echo.Context`; the error handler is `func(c *echo.Context, err error)`; `HTTPError.Message` is a string and a cause is attached with `Wrap`; Echo's sentinels such as `echo.ErrNotFound` are not `*HTTPError`, so status is read with `echo.StatusCode(err)`; `c.Response()` is an `http.ResponseWriter`; logging is `log/slog`; there is no `Timeout` or `Logger` middleware.

When a snippet from the web, a blog or this file disagrees with the code, the module source wins:

```bash
ls "$(go env GOMODCACHE)/github.com/labstack/echo/"
grep -n "func DefaultHTTPErrorHandler" "$(go env GOMODCACHE)"/github.com/labstack/echo/v5@*/echo.go
```

v5.4.0 is a security release (request scheme spoofing, `X-Real-IP` passed through by `Proxy`, JSONP callbacks, `MethodOverride` bypassing CSRF, open redirects, static files reached past route guards). A service on an older patch should be upgraded before anything cosmetic.

---

# 1. One central error handler, not an error helper per call site

The most common Echo slop is a helper every handler calls on failure, which logs and builds the 500 itself.

Bad:

```go
func serverError(err error) error {
	slog.Error("handler error", "error", err)
	return echo.NewHTTPError(http.StatusInternalServerError, "internal error")
}

if err != nil {
	return serverError(err)
}
```

Its flaws compound. It logs without the request, so the line has no route, method or user. To fix that, people thread `c` into it, then into every error mapper that calls it, and every call site changes. It cannot see the request's final state, so it cannot tell a client that left from a real fault.

Prefer: return the error and let one handler decide.

```go
if err != nil {
	return err
}
```

```go
e.HTTPErrorHandler = newErrorHandler()
```

Echo calls `e.HTTPErrorHandler` for whatever the handler chain returns. That is the one place that has the request, the error and the response together, so it is the one place that logs a failure and writes its body.

---

# 2. A plain error is already an opaque 500

Do not wrap every unexpected failure in `NewHTTPError(500, ...)`. Echo's default handler turns any error without a status into `500 {"message":"Internal Server Error"}` and never puts the error's text in the body (unless it is built with `exposeError`; see §9).

Bad:

```go
if err != nil {
	return echo.NewHTTPError(http.StatusInternalServerError, "failed to load user")
}
```

Prefer:

```go
if err != nil {
	return fmt.Errorf("load user: %w", err)
}
```

Use `HTTPError` for statuses you mean: 400, 401, 402, 403, 404, 409, 422, 429, 503. Use plain errors for "this should not have happened".

---

# 3. Attach a cause with `Wrap`; match a status with `echo.StatusCode`

When a deliberate non-500 failure has a cause worth logging (an upstream returned garbage, so 502), wrap the cause so the error handler can log it while the body stays generic:

```go
return echo.NewHTTPError(http.StatusBadGateway, "upstream unavailable").Wrap(err)
// or, from a sentinel, with the status text as its message:
return echo.ErrBadGateway.Wrap(err)
```

`Wrap` returns a new `*HTTPError`; it never changes the receiver, so wrapping a sentinel is safe. A package-level `*HTTPError` is still shared by every request: never assign to its `Code` or `Message`.

`HTTPError.Unwrap` returns the cause, so `errors.Is(err, context.Canceled)` sees through it.

**Trap:** a wrapped sentinel is no longer the sentinel. `errors.Is(err, echo.ErrBadRequest)` is false for every bind error, because the binder returns `echo.ErrBadRequest.Wrap(cause)`. Match on the status:

```go
if echo.StatusCode(err) == http.StatusBadRequest { ... }
```

---

# 4. The error handler's shape

Write it in the shape of Echo's own default handler, and delegate the body to it so `HEAD`, the JSON shape and errors that marshal themselves stay Echo's.

```go
func newErrorHandler() echo.HTTPErrorHandler {
	respond := echo.DefaultHTTPErrorHandler(false)
	return func(c *echo.Context, err error) {
		if r, _ := echo.UnwrapResponse(c.Response()); r != nil && r.Committed {
			return
		}
		status := echo.StatusCode(err)
		unexpected := status == 0
		if unexpected {
			status = http.StatusInternalServerError
		}
		if status >= http.StatusInternalServerError && (unexpected || errors.Unwrap(err) != nil) {
			slog.Error("handler error",
				"error", err, "status", status,
				"request_id", c.Response().Header().Get(echo.HeaderXRequestID),
				"method", c.Request().Method, "route", c.Path())
		}
		respond(c, err)
	}
}
```

What each part is for:

- **The committed check comes first.** Once headers are out, the status cannot change. It also makes a second call for the same request harmless (§11).
- **`echo.StatusCode`, never `errors.As(err, &he)` with `he *echo.HTTPError`.** `echo.ErrNotFound`, `echo.ErrMethodNotAllowed` and the other sentinels are not `*HTTPError`, and neither is `*echo.BindingError`; a handler that falls back to 500 when that assertion fails answers every unknown route and every bad query parameter with a 500.
- **It logs only an unexpected error or a 5xx with a cause.** A deliberate 503 with no cause ("not configured here") is an answer, not a fault. 4xx are the client's mistakes and do not belong at ERROR. Log `err` itself: `HTTPError.Error()` already includes the cause.
- **It reads `c.Path()`, the route pattern**, not `URL.Path` (§36).
- **It never writes the cause into the body.**

For `application/problem+json` bodies, delegate to `echo.ProblemDetailsHTTPErrorHandler(false)` instead of hand-building an RFC 9457 envelope; errors can implement `echo.ProblemErrorer` to supply their own problem.

---

# 5. Error mappers take the error, not the context

Domain errors are mapped to statuses in small switch functions. They need the error only.

Bad:

```go
func spendError(c *echo.Context, err error) error {
	switch {
	case errors.Is(err, billing.ErrInsufficientBalance):
		return echo.NewHTTPError(http.StatusPaymentRequired, err.Error())
	default:
		return serverError(c, err) // context threaded in only to log
	}
}
```

Prefer:

```go
func spendError(err error) error {
	switch {
	case errors.Is(err, billing.ErrInsufficientBalance):
		return echo.NewHTTPError(http.StatusPaymentRequired, err.Error())
	default:
		return err
	}
}
```

If a mapper needs `c`, it is usually writing a response (§7), which is a different job.

---

# 6. Do not log and return

A handler that logs an error and also returns it produces two lines per failure, and two alerts where alerting reads the logs.

Bad:

```go
if err != nil {
	slog.Error("load account failed", "error", err)
	return err
}
```

Prefer: return it wrapped with what the error handler cannot know.

```go
if err != nil {
	return fmt.Errorf("load account for %s: %w", accountID, err)
}
```

Log inside a handler only what is *not* returned: a best-effort read the answer goes without, a side effect that failed after the response was decided.

---

# 7. Return errors; do not write error responses from helpers

Bad:

```go
func badRequest(c *echo.Context, msg string) error {
	return c.JSON(http.StatusBadRequest, map[string]string{"error": msg})
}

if req.Amount <= 0 {
	return badRequest(c, "amount must be positive")
}
```

The response is written, the handler returns `nil`, and every middleware above it sees success: no error for the request logger, and a status that only the response knows.

Prefer:

```go
if req.Amount <= 0 {
	return echo.NewHTTPError(http.StatusBadRequest, "amount must be positive")
}
```

**Acceptable exception:** a documented domain refusal whose body the client parses (`{"reason":"insufficient_balance"}`). `HTTPError.Message` is a string, so such a body is either written with `c.JSON(status, body)` and the handler returns `nil` (fine for a 4xx, which is an answer and not a failure), or returned as an error type that carries its own status and JSON, which the default handler writes as is:

```go
type refusal struct {
	status int
	Reason string `json:"reason"`
}

func (r *refusal) Error() string                { return r.Reason }
func (r *refusal) StatusCode() int              { return r.status }
func (r *refusal) MarshalJSON() ([]byte, error) { return json.Marshal(map[string]string{"reason": r.Reason}) }

return &refusal{status: http.StatusPaymentRequired, Reason: "insufficient_balance"}
```

The error form keeps the refusal visible to middleware as an error; pick one form per service.

---

# 8. A request its own client cancelled is not a server error

When the client disconnects, net/http cancels the request's context and the next database or upstream call fails with `context.Canceled`. Logged as a 500 at ERROR, every closed browser tab becomes an alert.

Handle it in the error handler, by both conditions:

```go
func clientGone(c *echo.Context, err error) bool {
	return errors.Is(err, context.Canceled) &&
		errors.Is(c.Request().Context().Err(), context.Canceled)
}

// in the error handler, before logging a 5xx:
if clientGone(c, err) {
	slog.Info("request cancelled by client", attrs...)
	_ = c.NoContent(middleware.StatusCodeContextCanceled) // 499; nobody reads it
	return
}
```

Requiring **both** conditions matters:

- A `context.Canceled` raised while the request is still live is a cancellation *we* caused, and stays an error.
- `context.DeadlineExceeded` is a timeout. It is ours, never the client's.
- A different error on a request whose client left is still a fault.
- pgx reports a cancelled query as `timeout: context already done: context canceled`. The word "timeout" is its name for any ended context; it unwraps to `context.Canceled`.

Logging at INFO keeps the rate visible without alerting. Log at least once rather than not at all: a rising rate of cancellations points at a slow endpoint.

Bad, too broad:

```go
if errors.Is(err, context.Canceled) {
	return nil // hides our own cancellations and records a 200
}
```

---

# 9. Never expose errors in production

`echo.DefaultHTTPErrorHandler(true)` and `echo.ProblemDetailsHTTPErrorHandler(true)` put the cause in every error body: SQL, file paths, upstream URLs. Pass `false` outside development, and never derive it from a request.

---

# 10. Do not catch errors in middleware just to translate them

Bad:

```go
func errorMiddleware(next echo.HandlerFunc) echo.HandlerFunc {
	return func(c *echo.Context) error {
		if err := next(c); err != nil {
			var nf *NotFoundError
			if errors.As(err, &nf) {
				return c.JSON(http.StatusNotFound, ...)
			}
			return c.JSON(http.StatusInternalServerError, ...)
		}
		return nil
	}
}
```

That is a second error handler. It also only covers the routes the middleware wraps. Domain-to-status translation belongs in mappers (§5) or in the error handler itself.

---

# 11. A middleware that needs the final status runs the error handler

Until the error handler runs, the response's status is still 200. A middleware that records status after `next(c)` must not guess it from the error.

Bad:

```go
err := next(c)
status := echo.StatusCode(err) // a plain error records 0; a 499 decided by the handler records 500
```

Bad, and broken under any wrapping writer (`Gzip`, `BodyDump`):

```go
status := c.Response().(*echo.Response).Status
```

Prefer, as `RequestLogger{HandleError: true}` does:

```go
err := next(c)
if err != nil {
	c.Echo().HTTPErrorHandler(c, err) // the error handler answers now
}
_, status := echo.ResolveResponseStatus(c.Response(), err)
...
return err
```

`ResolveResponseStatus` returns the committed status once the handler has answered. Reach the `*echo.Response` itself with `echo.UnwrapResponse(c.Response())`, never a type assertion.

Returning `err` after handling it is what Echo's own middleware does. When the router calls the error handler again for the same error, the committed check (§4) makes that call do nothing. A custom error handler without that check double-logs.

---

# 12. Use `RequestLogger`, not a hand-rolled access log

`middleware.RequestLoggerWithConfig` takes `LogValuesFunc`, so it logs to `slog` with the fields you choose, and `HandleError: true` gives it the real status (§11).

```go
e.Use(middleware.RequestLoggerWithConfig(middleware.RequestLoggerConfig{
	HandleError:  true,
	LogStatus:    true,
	LogMethod:    true,
	LogRoutePath: true,
	LogLatency:   true,
	LogRequestID: true,
	LogValuesFunc: func(c *echo.Context, v middleware.RequestLoggerValues) error {
		if v.Latency > slowRequest {
			slog.Warn("slow request", "method", v.Method, "route", v.RoutePath, "status", v.Status,
				"ms", v.Latency.Milliseconds(), "request_id", v.RequestID)
		}
		return nil
	},
}))
```

Failures are the error handler's line (§4). A request logger that also logs every failed request at ERROR is a second line per failure (§6). The preset `middleware.RequestLogger()` does exactly that: it logs every returned error at ERROR, 4xx included, keyed by URI rather than route; configure your own instead.

A project-specific middleware that also emits analytics is fine; give it the §11 shape.

---

# 13. `ContextTimeout` for deadlines; not on every route

`middleware.ContextTimeout(d)` puts a deadline on the request context; when the handler returns an error that is `context.DeadlineExceeded`, it answers `503` with that cause wrapped. Do not hand-roll the same with `context.WithTimeout` and `c.SetRequest` in a custom middleware, and do not wrap `http.TimeoutHandler` with `echo.WrapMiddleware`: it answers from its own writer while the handler goes on using a pooled context (§19).

```go
api.POST("/render", h.render, middleware.ContextTimeout(30*time.Second))
```

Put timeouts where a slow dependency is called, not around every route. A handler that ignores its context is not stopped by any timeout middleware.

---

# 14. Know where each middleware runs

- `e.Pre(...)` runs **before routing**: URL rewrite, trailing slash, `MethodOverride` (which must be registered with `Pre`, or `_method` can skip CSRF).
- `e.Use(...)` runs **after routing, for every request**, including 404 and 405.
- `e.Group(prefix, mw...)` and `g.Use(mw...)` run for the group's routes, **and for unmatched paths under the prefix** (§15).
- Route middleware (`g.GET(path, h, mw...)`) runs for that route only.

Order inside `e.Use` matters. Put `RequestID` before anything that logs, so lines carry the id. Put `Recover` early, so a panic in a later middleware is caught. `Recover` returns the panic as an error (`*middleware.PanicStackError`, with the stack), so it reaches the central handler as a 500.

---

# 15. Group middleware also runs on 404s under the prefix

`Group.Use` registers catch-all `RouteNotFound` routes for `prefix` and `prefix/*`, so its middleware runs even for unknown paths.

Consequences:

- An auth middleware on `/api` runs, and may hit the database, for `/api/does-not-exist`.
- Two groups on the same prefix (`e.Group("/api", auth)` and `e.Group("/api", auth, membership)`) both register catch-alls. The last one decides what an unknown `/api/...` path passes through.
- A catch-all route (`e.Any("/*", spa)`) no longer sees `/api/...` paths: an unknown one answers 404 through the last group's middleware.

Prefer one group per prefix with sub-groups for extra middleware, or route-level middleware for a single route.

```go
api := e.Group("/api", auth)
gated := api.Group("", requireMembership)
gated.GET("/me", h.me)
```

`echo.Config{NoGroupAutoRegister404Routes: true}` turns the catch-alls off; then group middleware such as `CORS` no longer runs for unmatched paths, so check what relied on it.

---

# 16. Do not re-implement built-in middleware

Before writing middleware, check `middleware/`: `BodyLimit`, `RequestID`, `CORS`, `Secure`, `Gzip`/`Decompress`, `RateLimiter`, `KeyAuth`, `BasicAuth`, `CSRF`, `MethodOverride`, `Rewrite`, `Proxy`, `Static`, `ContextTimeout`, `RequestLogger`, `Recover`, the HTTPS and trailing-slash redirects.

Use their config structs and `Skipper` instead of path checks inside the middleware.

Bad:

```go
func limitBody(next echo.HandlerFunc) echo.HandlerFunc {
	return func(c *echo.Context) error {
		if c.Request().URL.Path == "/upload" {
			return next(c)
		}
		c.Request().Body = http.MaxBytesReader(c.Response(), c.Request().Body, 1<<20)
		return next(c)
	}
}
```

Prefer:

```go
e.Use(middleware.BodyLimit(middleware.MB))
api.POST("/events", h.events, middleware.BodyLimit(16*middleware.KB)) // tighter per route
```

A global limit runs before route middleware, so a route that needs a *larger* body is the one place a `Skipper` on the global limit is right.

---

# 17. Middleware is `func(next echo.HandlerFunc) echo.HandlerFunc`; keep it boring

- Return `next(c)` as is. Do not wrap errors from inner handlers in middleware.
- Do not `recover()` in your own middleware; `Recover` exists (deslop-go §57).
- Stop the chain by returning an error, not by writing a response and returning `nil` (§7).
- Configuration goes in the closure, not in package globals read per request.

---

# 18. Do not mutate the `Echo` instance after start

Fields on `*echo.Echo` (`HTTPErrorHandler`, `IPExtractor`, `SchemeExtractor`, `Binder`, `Validator`, `Logger`) and its routes are read concurrently by every request. Set them in the constructor, or pass them in `echo.NewWithConfig(echo.Config{...})`; never from a handler or a background goroutine.

---

# 19. `*echo.Context` lives exactly as long as the request

Echo pools contexts. After the handler returns, the context goes back to the pool and is `Reset` for another request. A goroutine that keeps `c` reads someone else's request.

Bad:

```go
go func() {
	h.audit(c.Request().Context(), userFrom(c).ID, c.Param("id")) // c is reused by then
}()
return c.NoContent(http.StatusAccepted)
```

Prefer: copy values out, and detach the context if the work must outlive the request.

```go
userID, id := userFrom(c).ID, c.Param("id")
ctx := context.WithoutCancel(c.Request().Context())
go h.audit(ctx, userID, id)
return c.NoContent(http.StatusAccepted)
```

---

# 20. Pass `context.Context` down, not `*echo.Context`

Services, stores and domain code take `context.Context` and plain values. `*echo.Context` stays in the handler layer.

Bad:

```go
func (s *Service) Profile(c *echo.Context) (Profile, error) {
	id := c.Get("user").(*User).ID
	...
}
```

Prefer:

```go
func (s *Service) Profile(ctx context.Context, userID int64) (Profile, error)
```

Use `c.Request().Context()` for every downstream call, so a client that leaves cancels the work (§8).

---

# 21. One typed accessor per context key

`c.Set`/`c.Get` are untyped. Do not scatter type assertions across handlers.

Bad:

```go
user := c.Get("user").(*User) // panics when middleware did not run
```

Prefer one accessor beside the middleware that sets it:

```go
const userKey = "user"

func userFrom(c *echo.Context) (*User, bool) {
	u, ok := c.Get(userKey).(*User)
	return u, ok
}
```

or Echo's generic `echo.ContextGet[*User](c, userKey)`, which returns `echo.ErrNonExistentKey` or `echo.ErrInvalidKeyType`: plain errors, so a handler that returns them answers 500.

Do not use `c.Set` to pass values between a handler and its own helpers; use parameters.

---

# 22. Do not wrap the context in a custom type

An `AppContext` struct embedding `*echo.Context`, plus an adapter that builds one per request so handlers can take `func(*AppContext) error`, adds a type every handler and test must know, and an adapter on every route. Use accessors (§21) for per-request values and handler struct fields (§23) for dependencies.

---

# 23. Dependencies go on a handler struct, not in the context

Bad:

```go
e.Use(func(next echo.HandlerFunc) echo.HandlerFunc {
	return func(c *echo.Context) error {
		c.Set("db", db)
		return next(c)
	}
})
```

Prefer:

```go
type Server struct{ db *pgxpool.Pool }

func (s *Server) handleMe(c *echo.Context) error { ... s.db ... }
```

---

# 24. Bind into a request DTO, never into a domain or database struct

Binding into a model lets a client set any field the struct exposes: `is_admin`, `balance`, `user_id`.

Bad:

```go
var u User
if err := c.Bind(&u); err != nil { ... }
store.Save(ctx, u)
```

Prefer:

```go
type updateSettingsReq struct {
	Language *string `json:"language"`
}

var req updateSettingsReq
if err := c.Bind(&req); err != nil {
	return err
}
```

Then map explicitly into the domain call.

---

# 25. Know what `c.Bind` binds, and in which order

`DefaultBinder.Bind` binds:

1. path parameters (`param` tags);
2. query parameters (`query` tags), **only for GET, DELETE, HEAD and QUERY**;
3. the body, by `Content-Type` (`json`, `xml`, `form`, multipart), **skipped when `ContentLength == 0`**; any other content type is a 415.

Each step overwrites the previous one. Headers are never bound by `Bind`.

Traps:

- A field tagged `param:"id" json:"id"` takes the **body's** id, not the path's. A client can address a different resource than the URL names. Keep identity from the path out of the body DTO, or read it with `c.Param`.
- A POST with `?page=2` does not bind `page`.
- A request without a body binds nothing and returns no error. Required fields need validation (§28).

When only one source applies, bind only that source:

```go
echo.BindBody(c, &req)
echo.BindQueryParams(c, &q)
echo.BindPathValues(c, &p)
echo.BindHeaders(c, &h)
```

---

# 26. Bind errors are already 4xx; return them

`Bind` returns a 400 whose body is `{"message":"Bad Request"}` and whose cause (the parser's detail) is wrapped for the error handler, or a 415 for an unsupported content type. Replacing it discards the cause and turns the 415 into a 400.

Bad:

```go
if err := c.Bind(&req); err != nil {
	slog.Warn("bind failed", "error", err)
	return echo.NewHTTPError(http.StatusBadRequest, "invalid request")
}
```

Prefer:

```go
if err := c.Bind(&req); err != nil {
	return err
}
```

Replace the message only on purpose (a client that shows it, say), and keep the cause: `echo.NewHTTPError(http.StatusBadRequest, "amount must be a number").Wrap(err)`.

---

# 27. Use the value binders for query and path scalars

Bad:

```go
idStr := c.QueryParam("id")
if idStr == "" {
	return echo.NewHTTPError(http.StatusBadRequest, "id required")
}
id, err := strconv.ParseInt(idStr, 10, 64)
if err != nil {
	return echo.NewHTTPError(http.StatusBadRequest, "id must be a number")
}
limit := 50
if s := c.QueryParam("limit"); s != "" { ... }
```

Prefer:

```go
var id int64
limit := int64(50)
if err := echo.QueryParamsBinder(c).
	MustInt64("id", &id).
	Int64("limit", &limit).
	BindError(); err != nil {
	return err
}
```

or the generic helpers: `echo.QueryParamOr[int64](c, "limit", 50)`, `echo.PathParam[int64](c, "id")`, `echo.FormValueOr[...]`. Their errors are `*echo.BindingError`, a 400 that renders `{"field":"id","message":"..."}`. `echo.PathValuesBinder(c)` and `echo.FormFieldBinder(c)` are the fluent forms for path and form values.

**Trap:** `echo.QueryParam[T]`, `echo.PathParam[T]` and `echo.FormValue[T]` return `echo.ErrNonExistentKey` for a missing key. That is a plain error, so returning it answers 500. Use the `...Or` form with a default, or `MustInt64` and friends on a binder for a required value.

When a malformed path id must answer 404 rather than 400, a hand parse that returns `echo.ErrNotFound` is a deliberate status, not slop.

---

# 28. One validator, called once, after binding

Register one `e.Validator` (commonly go-playground/validator) and call `c.Validate(&req)` after `Bind`. Have it return a 400, or wrap its error into one.

```go
if err := c.Bind(&req); err != nil {
	return err
}
if err := c.Validate(&req); err != nil {
	return echo.NewHTTPError(http.StatusBadRequest, err.Error()).Wrap(err)
}
```

Without a registered validator, `c.Validate` returns `echo.ErrValidatorNotRegistered`, a 500. Do not add a second validation stack, and do not re-validate typed values deeper in the handler (deslop-go §49). If the project validates by hand and has no validator, keep that style; do not introduce a library to clean up three checks.

---

# 29. Bound every body

Without a limit, `Bind` and `io.ReadAll(c.Request().Body)` read whatever the client sends. Set `middleware.BodyLimit` globally, tighter per route where the body is small (§16). Never read a body unbounded by hand.

---

# 30. Read a path param once, by name

Do not parse `c.Request().URL.Path` with `strings.Split` to find an id; declare `:id` in the route and read `c.Param("id")` (or bind it, §27).

---

# 31. Use the response helpers, and return their error

Bad:

```go
b, _ := json.Marshal(resp)
c.Response().Header().Set("Content-Type", "application/json")
c.Response().WriteHeader(http.StatusOK)
c.Response().Write(b)
return nil
```

Prefer:

```go
return c.JSON(http.StatusOK, resp)
```

The helpers are `c.JSON`, `c.NoContent`, `c.String`, `c.HTML`, `c.XML`, `c.Blob`, `c.Stream`, `c.File`, `c.FileFS`, `c.Attachment`, `c.Inline`, `c.Redirect`. Return the helper's error rather than dropping it; the router hands it to the error handler.

---

# 32. After the first byte, the status is final

Once the response is committed, an error can no longer become a 500. `WriteHeader` on a committed response logs "echo: response already written to client" and does nothing. The error handler's committed check (§4) returns early.

`c.JSON` holds the status until the value has serialised, so a marshalling error still reaches the error handler as a 500. Writing to `c.Response()` directly has no such grace.

So for streams, files and large bodies:

- do everything that can fail (lookup, authorization, opening the source) **before** writing;
- a write that fails mid-body is almost always a client that left. Do not expect it to produce an error response, and do not log it at ERROR.

---

# 33. `HEAD` and the body shape are the default handler's job

The default error handler answers `HEAD` with no body, writes JSON otherwise, and lets an error that implements `json.Marshaler` write its own body (§7). A custom handler that writes `c.JSON` itself loses all three; delegate to the default (§4), or to `echo.ProblemDetailsHTTPErrorHandler` for RFC 9457 bodies.

---

# 34. Do not set headers Echo sets

`c.JSON` sets `Content-Type: application/json` when none is set. `middleware.RequestID` sets `X-Request-Id` on the response. Read it back with `c.Response().Header().Get(echo.HeaderXRequestID)`; do not generate a second id.

---

# 35. Cache and security headers belong in one place

Repeating `c.Response().Header().Set("Cache-Control", "no-store")` in many handlers is a route-group middleware or a `Secure` config, unless the header genuinely differs per handler.

---

# 36. Log and measure the route pattern, not the URL

`c.Path()` is the registered pattern (`/api/products/:id/images`), which has bounded cardinality; `c.RouteInfo()` gives the matched route's method, path, name and parameter names. `c.Request().URL.Path` carries ids and makes every request a new series in metrics and a new key in dashboards.

---

# 37. Register routes in one place, by group

A route table in one function per surface (`NewRouter`, `registerMediaRoutes`) makes middleware coverage readable. Do not register routes from `init()` or from inside handlers. Use `e.RouteNotFound` for a custom 404 instead of `e.Any("/*")` when the intent is "not found".

---

# 38. Do not hand-roll a router inside a handler

Bad:

```go
e.Any("/api/v1/*", func(c *echo.Context) error {
	switch {
	case strings.HasPrefix(c.Request().URL.Path, "/api/v1/users"): ...
	}
})
```

Register the routes.

---

# 39. Serve with timeouts and a graceful shutdown

`e.Start(addr)` is for examples: it gives you `StartConfig`'s defaults (a 30 s `ReadTimeout`, no `ReadHeaderTimeout` or `IdleTimeout`) and its own signal handling. Use `echo.StartConfig` and set what the deployment needs:

```go
sc := echo.StartConfig{
	Address:         ":8080",
	GracefulTimeout: 10 * time.Second,
	BeforeServeFunc: func(s *http.Server) error {
		s.ReadHeaderTimeout = 5 * time.Second
		s.IdleTimeout = 120 * time.Second
		return nil
	},
}
if err := sc.Start(ctx, e); err != nil {
	return err
}
```

`Start` returns when `ctx` ends and the graceful shutdown finishes; it does not report `http.ErrServerClosed`. A service that needs its own drain wraps `e` in an `http.Server` instead (`Handler: e`) and calls `srv.Shutdown(ctx)`. `Shutdown` lets in-flight requests finish; it does not cancel their contexts.

`ReadTimeout` does not cancel a running handler's context; a long handler keeps a live context after it expires. `WriteTimeout` truncates long responses (streams, large files), so leave it unset when you serve those and bound the slow paths with `ContextTimeout` (§13).

---

# 40. Set `IPExtractor` (and `SchemeExtractor`) for your deployment

Without `e.IPExtractor`, `c.RealIP()` is the direct peer's address. That is safe with nothing in front of the app; behind a proxy, every client has the proxy's address, so `RateLimiter` (which keys on `RealIP` by default) throttles all of them as one, and logs show one IP.

Do not fix that by reading `X-Forwarded-For` yourself or by `echo.LegacyIPExtractor()`: both trust whatever the client sends, and a spoofed address then reaches the rate limiter, the logs and the `Proxy` middleware. Pick the extractor for the deployment:

```go
e.IPExtractor = echo.ExtractIPDirect()                                    // nothing in front of the app
e.IPExtractor = echo.ExtractIPFromXFFHeader()                             // behind proxies in private networks
e.IPExtractor = echo.ExtractIPFromXFFHeader(echo.TrustIPRange(cdnRange)) // behind a CDN with public ranges
```

The outermost proxy must overwrite, not pass through, the client's forwarding headers.

`c.Scheme()` trusts `X-Forwarded-Proto` only from loopback, link-local and private peers. A proxy that reaches the app from a public address (Cloudflare or a cloud load balancer to a public origin) needs `e.SchemeExtractor = echo.ExtractSchemeFromHeaders(echo.TrustIPRange(...))`; otherwise `HTTPSRedirect` loops and `Secure` stops sending HSTS.

---

# 41. Do not serve files with hand-built paths

`c.File(filepath.Join(dir, c.QueryParam("name")))`, or the same with a `*` wildcard, reaches any file under the process's working directory, Echo's default `Filesystem`. Use `e.Static`, `e.StaticFS`, `middleware.StaticWithConfig`, or `c.FileFS(name, os.DirFS(dir))`, which rejects `..`, on a patched Echo (§0). `Static` registered with `e.Use` runs before route and group middleware, so route guards do not protect what it serves; put the guard on the static mount itself.

---

# 42. Test through the router

`e.ServeHTTP(rec, req)` runs routing, middleware, binding and the error handler: what the client actually gets.

```go
e := NewRouter(cfg, deps...)
rec := httptest.NewRecorder()
e.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/me", nil))
require.Equal(t, http.StatusOK, rec.Code)
```

Calling a handler directly returns its error and writes nothing for it. That is fine for unit-testing a handler's logic. Then assert on the returned error, or pass it to the error handler under test, `e.HTTPErrorHandler(c, err)`, to assert the response. Do not assert that a direct call "returned 500": with plain errors it returns an error, not a status.

When calling a handler directly with a path parameter, set the route and its values:

```go
c := e.NewContext(req, rec)
c.SetPath("/api/products/:id/details")
c.SetPathValues(echo.PathValues{{Name: "id", Value: "sample-product"}})
```

`echotest.ContextConfig{PathValues: ..., JSONBody: ...}.ServeWithHandler(t, h, echo.HTTPErrorHandler(handleError))` builds these for you, with two traps: it runs on a fresh `echo.New()`, so the project's `Validator`, `Binder` and extractors are absent; and it recognises the error handler only as an `echo.HTTPErrorHandler` value, so a bare `func` silently falls back to the default handler.

---

# 43. Test the error handler with a table

The error handler is the one function every failure passes through. Test it directly: a plain error gives an opaque 500 and an ERROR line with route and request id; an `HTTPError` 4xx gives its message and no log; `echo.ErrNotFound` and a `BindingError` keep their status; a deliberate 5xx without a cause is not logged; a client-cancelled request gives 499 at INFO; a deadline stays a 5xx; the cause never appears in the body.

---

# 44. Do not hide `*echo.Context` behind an interface to mock it

An interface listing the context methods a handler uses, so a test can pass a fake, tests the fake. Build a real context with `e.NewContext(httptest.NewRequest(...), httptest.NewRecorder())`, or go through `e.ServeHTTP` (§42).

---

# 45. A pool that connects nowhere reproduces cancellation without a database

To test §8 end to end, point a `pgxpool` at an unreachable address (`postgres://u:p@127.0.0.1:1/x?connect_timeout=2`) and send a request whose context is already cancelled. The pool's `Acquire` returns `context.Canceled` exactly as in production, through the real middleware. The same pool with a live context gives a real connection error, so it doubles as the 500 case.

---

# 46. Search patterns to audit

```bash
# error helpers that log, build 500s, or carry the context
grep -rnE 'func [a-zA-Z]*(Error|Err|Fail|Abort)[a-zA-Z0-9]*\(.*(\*echo\.Context|err error)' --include='*.go'
grep -rnE 'NewHTTPError\(http\.StatusInternalServerError' --include='*.go'
grep -rnE 'slog\.(Error|Warn)\(' --include='*.go' -A1 | grep -E 'return .*err'   # log and return (§6)

# status guessed or matched outside the error handler
grep -rnE '\*echo\.HTTPError|errors\.Is\([a-zA-Z]+, echo\.Err' --include='*.go'   # (§3, §4)
grep -rnE 'HTTPErrorHandler|ErrorHandler\(true\)' --include='*.go'                # (§4, §9)
grep -rnE '\(\*echo\.Response\)' --include='*.go'                                 # (§11)

# hand-rolled or noisy middleware
grep -rnE 'MaxBytesReader|recover\(\)|TimeoutHandler|context\.WithTimeout\(c\.Request' --include='*.go'
grep -rnE 'middleware\.RequestLogger\(\)' --include='*.go'                        # (§12)

# context misuse
grep -rnE 'go func\(' --include='*.go' -A5 | grep -E '\bc\.(Request|Param|Get|QueryParam|Response)'
grep -rnE 'func .*\*echo\.Context' --include='*.go' | grep -vE '^[^:]*(handler|api|http|server|route|middleware)'
grep -rnE 'c\.Get\("?[a-zA-Z_]+"?\)\.\(' --include='*.go'

# binding
grep -rnE 'c\.Bind\(&(u|user|model|m|entity)\b' --include='*.go'
grep -rnE 'c\.Bind\(' --include='*.go' -A1 | grep -E 'NewHTTPError\('            # bind error replaced (§26)
grep -rnE 'strconv\.(Atoi|ParseInt|ParseUint|ParseBool|ParseFloat)\(c\.(QueryParam|Param|FormValue)' --include='*.go'
grep -rnE 'echo\.(QueryParam|PathParam|FormValue)\[' --include='*.go'             # missing key is a 500 (§27)
grep -rnE '`[^`]*param:"[^"]+"[^`]*json:"[^"]+"' --include='*.go'                # path and body on one field (§25)

# routing, server, security
grep -rnE 'URL\.Path' --include='*.go'                                            # logged or split? (§30, §36)
grep -rnE '\.Group\("[^"]*"' --include='*.go'                                     # two groups on one prefix? (§15)
grep -rnE '\.Start\(|StartConfig|RealIP\(\)|IPExtractor|SchemeExtractor|X-Forwarded-For' --include='*.go'

# tests that bypass the router
grep -rnE 'NewContext\(' --include='*_test.go' | wc -l
grep -rnE 'ServeHTTP\(' --include='*_test.go' | wc -l
```

Each hit is a question, not a verdict.

---

# 47. What stays

Do not remove these in the name of cleanup:

- `HTTPError` for statuses the client is meant to act on, with messages it can show.
- Documented domain refusal bodies (`{"reason": "..."}`) that clients parse (§7).
- `Recover`, `RequestID`, `BodyLimit`, and authentication and authorization middleware, including the ones that look redundant.
- Explicit request DTOs and the explicit mapping out of them.
- A typed accessor per context key.
- Logging inside a handler for what is not returned: best-effort reads, side effects after the answer is decided (§6).
- Per-route `BodyLimit` and `ContextTimeout` where a route really differs.
- A custom error handler. The goal is one good one, not none.

---

# 48. The Echo de-slop test

For every change, answer:

1. Does every failure now leave the handler as a returned error?
2. Is there exactly one place that picks a status for an unexpected error, logs it, and writes its body?
3. Does every log line about a failed request carry the route pattern and the request id?
4. Does every middleware that reports a status report the one the client got?
5. Did any status code, response body or log level change? If so, was it on purpose, and are its consumers (app, dashboards, alerts) still right?
6. Does a test drive the change through `e.ServeHTTP`?

If the answer to 5 is "yes, by accident", revert that part.

---

# 49. Most important rule

Do not trade Echo slop for Go slop. Replacing `serverError(c, err)` with a `Responder` interface, an error registry or a middleware factory is not a cleanup. The cleanup is: return the error, and make the one error handler right.

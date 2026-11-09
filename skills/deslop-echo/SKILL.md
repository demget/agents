---
name: deslop-echo
description: 'Use when cleaning up or reviewing a Go service built on labstack/echo v5 (error handler, middleware, binding), and before finishing any change to those. Triggers on "de-slop this Echo code", "make this idiomatic Echo", "use Echo''s error handler", "echo best practices", /deslop-echo. Pair with deslop-go. Not for Gin, Chi, Fiber, plain net/http, or Echo v4 code.'
---

# Echo de-slop

The full law lives in `deslop-echo.md` beside this file: numbered rules, each with the bad pattern and what to write instead, checked against Echo v5.4.0 source. **Read it before touching code.** This file only tells you how to run it.

The single rule everything else derives from:

> Handlers return errors; one error handler turns them into responses. Echo already does binding, status, logging hooks and the middleware chain, so use them instead of rebuilding them in helpers.

## Running it

1. **Confirm v5 first** (§0). Read `go.mod` for `github.com/labstack/echo/v5`; on `/v4`, stop, because the signatures and behaviours here are v5's. When a rule and the code disagree, read the module's source in `$(go env GOMODCACHE)/github.com/labstack/echo/v5@<version>` instead of trusting memory or a blog post.
2. **Find the error path** before anything else: `e.HTTPErrorHandler`, every helper that builds an `HTTPError` or logs inside a handler, and every middleware that reads a status. §1–§11 is where most Echo slop lives.
3. **Audit with the grep list** (§46), then work route group by route group: errors, then middleware, then binding, then responses.
4. **Change behaviour only on purpose.** Status codes, response bodies and log levels are contracts with clients, dashboards and alerting. When a cleanup changes one, say so and check its consumers.
5. **Prove it through the router.** Tests drive `e.ServeHTTP` so middleware, binding and the error handler run (§42). Then run the project's own checks.

## What this skill does not license

§47 lists what stays: `HTTPError` for intended statuses, `Recover`, `RequestID`, `BodyLimit`, explicit request DTOs, typed context accessors, documented domain refusal bodies, and every authentication and authorization check. Deleting a guard to make the code shorter is not a cleanup.

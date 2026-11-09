---
name: deslop-go
description: >-
  Strip defensive over-engineering and AI slop out of a Go codebase — `any` and
  `map[string]any` carried through the app, conversion helpers, fallback-to-zero
  returns, nil guards on required fields, one-implementation interfaces,
  pass-through wrappers, builders, factories and mapper layers — and leave code
  that is concrete, boring and traceable. Use when the user says "de-slop this
  Go code", "this looks AI-generated", "simplify the Go", "too many
  interfaces/abstractions", "clean up the over-engineering", "make this
  idiomatic Go", or invokes /deslop-go. Also use before finishing a Go
  refactor whose whole point was reducing complexity. Not for adding features,
  not for performance work, and not for non-Go code.
---

# Go de-slop

The full law lives in `deslop-go.md` beside this file — 79 numbered rules, each with the bad
pattern and what to write instead. **Read it before touching code.** This file only tells you
how to run it.

The single rule everything else derives from:

> Validate untrusted data at the boundary. Use concrete types everywhere else.

## Running it

Work feature by feature, not file by file. For each one (§76 has the long form):

1. Find where data enters — HTTP, queue, database, webhook, config.
2. Give that input a concrete type and decode into it once.
3. Follow the data inward, deleting the `any`, the type assertions, the generic maps, the nil
   guards, the converters, the duplicate DTOs and the interfaces that only ever had one
   implementation.
4. Collapse forwarding layers and delete the abstractions left with nothing behind them.
5. Run the project's own checks: `go test ./...`, `go vet ./...`, `gofmt` on the files you
   changed.

§73 lists the grep patterns worth auditing; start there when the codebase is unfamiliar.

## What this skill does not license

It is a complexity cleanup, not reckless deletion. §77 enumerates what stays: boundary
validation, meaningful error wrapping, legitimate nil handling, context propagation,
`defer rows.Close()`, transaction rollback safety, mutexes over real shared state, and every
security check. Behaviour does not change to satisfy a style preference.

And §79: do not trade one slop for another. Replacing a bare type assertion with a three-step
comma-ok dance that returns `""` is not a cleanup — fixing the type is.

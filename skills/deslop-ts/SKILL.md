---
name: deslop-ts
description: >-
  Strip defensive over-engineering and AI slop out of TypeScript — `unknown` and
  `Record<string, unknown>` carried through the app, `asX()` extractors, fake
  runtime validation of already-typed values, silent empty fallbacks, defensive
  optional chaining, one-implementation interfaces, pass-through wrappers,
  duplicate DTOs, mappers, builders and factories — and leave code that trusts
  the type system. Use when the user says "de-slop this TypeScript", "this looks
  AI-generated", "simplify the TS", "too many helpers/abstractions", "clean up
  the over-engineering", "make this idiomatic TypeScript", or invokes
  /deslop-ts. Also use before finishing a TS refactor whose whole point was
  reducing complexity. This is about code, not
  interfaces or visual design.
---

# TypeScript de-slop

The full law lives in `deslop-ts.md` beside this file — 78 numbered rules, each with the bad
pattern and what to write instead. **Read it before touching code.** This file only tells you
how to run it.

The single rule everything else derives from:

> Validate untrusted data once at the boundary. Trust typed application code everywhere else.

## Running it

Follow the data, not the file list. §76 is the before-change review, in short:

1. Find the trusted and untrusted boundaries — HTTP, queue, webhook, database, config.
2. Validate and type that input once, at the edge.
3. Ask whether each broad type inward of the edge is deliberate or accidental. Usually it is
   accidental, and the fix is the root type rather than another `asX()` at the call site.
4. Delete what the precise type made unnecessary: the extractors, the narrowing, the
   `typeof` guards on values the compiler already knows, the fallbacks to `{}` and `""`.
5. Collapse forwarding layers and remove the abstractions left with nothing behind them (§69).
6. Run the project's own checks — the type checker first, then tests and lint.

§70 is the pass to run over anything an agent wrote; §77 is the ten-question review of your own
diff before you call the work done.

## What this skill does not license

§73 and §74: defend against external uncertainty, never against your own typed code. Keep the
handling for API failures, not-found rows, nullable database columns, malformed input, parse
failures, authorization and security checks. Business logic, public API behaviour, event names
and persistence formats do not change here — this is complexity reduction only.

And §78: do not trade one slop for another. Replacing a cast with a chain of narrowing that
bottoms out in `return {}` is not a cleanup; fixing the type is.

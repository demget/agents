---
name: agents-md
description: >-
  How to write and maintain agent context files — AGENTS.md, nested instruction files, the gitignored local file, docs/ — so they stay short enough to be read and hold only what code cannot show. Use whenever you are about to create or edit any of those files, when the user says "remember this", "add this to AGENTS.md", "note this down", "document this" or "update the docs", when deciding where a fact, rule or lesson should live. Owns the admission test, the routing table, the form of a rule, the root-file skeleton and the docs/ tiers.
---

# Context files

An instruction file is read on every turn, for every task, including the ones it does not apply to. Code is read on demand. So the root file holds only rules that change the agent's decisions across the repo and cannot be derived from the code; everything else lives where it is read when needed. Keep the root file short enough that its important rules remain easy to find; move area-specific guidance to scoped files.

## The admission test

Before adding a line to any instruction file, answer three questions. What would an agent get wrong without it? If reading the relevant code answers that, leave it out. Will it be read at the moment it matters, or is it the 200th bullet in a file nobody scans?

## Where a thing goes

Cheapest enforced tier first. A thing goes to the first tier that can hold it.

1. **Code.** How the code works, local traps, invariants: a test that fails, a type, a validation, a name, a present-tense comment at the trap. The best memory is a test.
2. **Tooling.** Anything a machine can enforce: a hook, a lint, a Makefile target, a CI check. Claude hooks do not reach Codex; if the hazard is cross-tool, pair the hook with a rule.
3. **Scoped files.** A rule local to one area: a nested `AGENTS.md` in that directory. A decision and its reasons, a constraint spanning components, a trap hard to discover from source, a verified fact about an external system: a `docs/internals/` page. A procedure used sometimes (a workflow, a checklist, how to drive a tool): a skill.
4. **The root file.** A rule that changes decisions repo-wide and is not derivable from code. One or two sentences.
5. **History.** The commit message or PR for why something changed; the gitignored local file for instance-specific values. Or nowhere.

A fact that fails the test is deleted, not moved. Git history keeps every earlier version of the file, so nothing needs a new home to be safe; the working file holds only what passes.

Never in an instruction file or a docs page: control-flow narration, per-file catalogs, feature or test inventories, PR summaries, status ("SHIPPED", "not yet exercised"), dated amendments ("Amended 2026-…"), rejected alternatives at length, incident stories, lab-notebook fact dumps, anything a reader gets by opening the code. Prose describing code rots silently when the code changes; the code does not.

## The form of a rule

- Present tense, imperative or declarative, written for a reader who has never seen an earlier version. No dates, no "no longer", no "after the X incident".
- At most two sentences, with a bold lead phrase naming the rule. If it needs more, it is a docs page with a one-line pointer here.
- The why is one clause, and only when the rule looks wrong without it: "Never `pkill -f` — your own agent process has this worktree's path in its argv."
- Replace, do not append. Find the existing line on the topic and rewrite it in place; two accounts of one rule is how files double.
- Provenance ("verified on codex 0.153.4") is allowed on a load-bearing fact that is not obvious from code. That is a constraint with evidence, not history.
- A rule that exists to stop re-litigating a decision states the decision and the channel to challenge it ("if a rule here fights the task, say so and get sign-off"), not the debate.

## The form of a docs paragraph

A docs page is written, never assembled. Existing text being rewritten is a list of facts to check, not prose to keep.

- A paragraph exists only if you can finish "without this, the next person would ___" with a specific wrong change. That sentence, turned around, is usually the paragraph. Three things must hold: reading the code would not tell you; no single file can hold it (one file means a comment at the trap, every file means a root rule); it stays true after the next three changes.
- One constraint per paragraph, about forty words, rarely over sixty: what must hold, and the one-clause reason. Present tense.
- Link to the file that enforces it instead of describing the mechanism. A data flow, a field list, a step-by-step of what a function does is the code's job.
- Before writing a fact, grep the code for it. A comment already at the trap makes the docs sentence a link, not a restatement; a third copy rots first.
- Provenance only as "verified on <version>" when the fact is load-bearing and not obvious. No dates of change, no incident stories.
- A page is 200–700 words with one durable reason to exist. Over that, it is two pages or it is narrating.

## Root-file skeleton

Use only the sections the repo has real content for, in roughly this order. Each exists because of a category of mistake it prevents.

1. **What this is** — one paragraph: what the repo is and what it is not.
2. **Non-negotiables** — three to five things never compromised on.
3. **A note from the maintainer** — values, "these are good defaults, the developer's word overrides", hazards particular to how agents work here.
4. **Glossary** — shared vocabulary only, not a feature index.
5. **Ways to hurt yourself** — numbered footguns, each with its one-clause present-tense reason.
6. **The common defect** — "the most common defect in this repo is X; before calling work done, walk this list."
7. **Dev loop** — install, run, ports, sharing.
8. **Test data.**
9. **Verifying** — the smallest proof, what not to run, the test philosophy in three lines.
10. **Commits and pull requests.**
11. **Documentation** — the tiers below and the admission test for docs.
12. **Plans and work artifacts** — what never gets committed.
13. **How it works** — ONE paragraph plus a link to the internals overview.
14. **Where code lives** — one line per top-level directory.
15. **Taste** — three to six lines, the last one the challenge channel.
16. **Additional tips.**

## docs/ tiers

- `docs/internals/` — architectural decisions and their reasons, constraints that span components, implementation traps hard to discover from source, verified facts about external systems. Link to the source instead of copying it. When a decision changes, rewrite or remove the text; never append a second account. A new page needs a distinct, durable reason to exist.
- `docs/user/` — helps users accomplish tasks, in the shipped product's voice, no repo tooling or source paths.
- `docs/operations/` — maintainer setup, release and debugging runbooks.
- `docs/README.md` — an index split by audience.

A one-person harness may need only `docs/internals/`, and often only three or four pages of it. Do not create empty tiers, and do not create a page to give displaced text somewhere to live. The form above is the bar for every paragraph on every page.

## Private versus tracked

The gitignored local file (`CLAUDE.local.md`) holds instance-specific values: hosts, account ids, where credentials live, the deploy procedure. It is still present-tense reference, not a diary; a dated narrative belongs in commits or in a log outside the instruction files. Nothing personal or instance-specific goes in the tracked file.

## Two tools, one file

`AGENTS.md` is the instruction file, at the root and nested; Claude Code and Codex both load it natively (verified on Claude Code 2.1.278 and Codex 0.155.0). A `CLAUDE.md` is only an alias for older setups: a symlink to `AGENTS.md`, never a second real file. Skills are authored once in `.agents/skills` as real directories, and `.claude/skills` is one symlink to `../.agents/skills`, never a per-skill mirror or a second copy.

## When asked to remember something

Route it with the table. If it lands in an instruction file, write it in rule form in the most specific file that governs the area. Say where you put it and why. If it is history, say it belongs in the commit message and offer that instead.

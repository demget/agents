---
name: commit
description: Use whenever you are about to create a git commit — when the user asks to commit, ship or push work, or when finishing a task means committing pending changes. Triggers on "commit this", "push it", /commit. "Land it" belongs to the land skill.
---

# Commit

Commit what's pending in focused commits. When asked to push or ship, also rebase onto the remote and push. Arguments, if provided, are extra constraints (a message to use, "only the auth changes").

The global rules on project commit style, branching, rebasing and attribution apply; this skill adds the procedure.

## Rules

1. **Conventional Commits.** `<type>(<scope>): <description>` with a type from `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `style`, `build`, `ci`, `chore`, `revert`. Scope is optional but preferred when it names the surface. Imperative, lowercase, no trailing period, plain language. An optional body after a blank line says *why*, not which files changed.
2. **One concern per commit.** If the message needs "also", split it. Bad: `fix: fixed auth bug and also updated README`. Good: `fix(auth): reject expired refresh tokens` and `docs(readme): document token lifetime`.
3. **Stage explicit paths.** `git add <paths>` for the files being committed; never `git add -A`, `git add .` or `git add -u`, because other sessions may have unrelated work in the same tree.
4. **Never bypass hooks.** No `--no-verify` unless the user explicitly asks. If a hook fails, stop and report its output; fixing it is a separate decision.

## Procedure

1. `git status` and `git log --oneline -5` as separate Bash calls; permission patterns match the command prefix, so don't chain them with `&&`.
2. Group the pending changes by concern and review each group with `git diff <files>`.
3. For each group: `git add <files>`, commit, and report the files and message.
4. Only when pushing: `git pull --rebase`, then `git push`. If the push is rejected because the remote advanced, rebase again and re-push; never resolve with a merge.
5. Finish with `git status` and report the commits created and whether they were pushed.

## Stop and ask the user if you hit

- A rebase conflict: report it; don't resolve or abort it blindly.
- A push still rejected after one rebase, or any sign the remote was force-moved.
- Detached HEAD, an in-progress merge or rebase, or a branch other than the expected one.
- A hook failure.

Never reach for `git reset --hard`, `git checkout -f`, `git clean -f` or a force push to get unstuck; those are what lose work.

---
name: babysit
description: >-
  Use when the user asks to monitor, watch or babysit a pull request through CI and review ("babysit it", "watch the PR", "get it green"), or when land reaches its babysitting step. Waits with one watcher, fixes real CI failures and review findings, and reports the PR ready; it merges only when the user asked for the merge.
---

# Babysit a PR

A request to babysit is the explicit request a "do not wait for or poll CI unless asked" rule waits for. It does not authorize merging.

## Wait with one watcher

Never write your own watcher, polling loop or `sleep` loop, and never run two watchers on one PR: every watcher on a GitHub account shares one rate limit.

**In T3 Code, use `watch_pull_request`.** Handle the checks and comments that already exist, then call it and end your turn. T3 wakes you when a check fails, the required checks pass, someone comments or reviews, or the branch conflicts.

- Only the thread that owns the PR watches it. A delegated child (a council member, any `delegate_task` task) never calls `watch_pull_request`.
- A wake is news, not a merge decision; check the gate yourself.
- Unwatch when you stop, whether ready, blocked or asking a question: a watched thread stays in Working and out of the user's inbox. A merge or close ends the watch on its own.
- "Stopped watching, could not read it" usually means the GraphQL limit is spent. Check `gh api rate_limit --jq .resources.graphql`; if `remaining` is near 0, wait for `reset` with one background command, then watch again.

**Everywhere else, use `pr-wait`:**

```bash
~/.agents/skills/babysit/scripts/pr-wait <pr> [--repo owner/name] [--until green|ready|any-change]
```

It prints one line per event and exits 0 when the condition is met or the PR merges, 1 when it needs you (a required check failed, conflicts, unresolved threads, PR closed) and 2 on bad input. Use `--until green` unless the repository has Greptile or Macroscope reviewing its PRs; `ready`, the default, waits for one of them and never finishes without. In Claude Code, run it with the Monitor tool (`timeout_ms: 3600000`) so each line wakes you. Start it again after each push, after handling an exit 1 and after a resume; it remembers what it reported. If it says another pid already watches the PR, do not start a second.

With either watcher, when an event needs no action, end the turn without a message. Never post or say "still waiting".

## GitHub rate limits

`gh pr create`, `gh pr view` and `gh pr checks` use GraphQL. When it is spent, REST has its own limit: read the PR with `gh api repos/<owner>/<repo>/pulls/<n>` and its checks with `gh api repos/<owner>/<repo>/commits/<sha>/check-runs`.

## CI failures

Act only on runs for the latest head. Read the failing job's log before changing code, and tell a repository failure from an infrastructure flake: a runner that died, a network timeout, a cancelled job. Reproduce a repository failure locally with the command the job runs, fix it, prove the fix and push. Re-run a flake once with `gh run rerun <id> --failed`; report it if it fails again.

## Review comments

Act only on comments newer than the latest push. Verify every finding against the source before changing code. Fix the real ones; answer the rest with a written reason, then resolve the thread. Read any rules a review bot cites (such as `.macroscope/check-run-agents/*.md`) before replying to it. CodeRabbit is advisory: weigh its findings like any other, but never wait or hold a merge for it.

Write every comment you post on the user's behalf like this: lead with the conclusion, cite the code, check or reproduction behind it, keep it short with no thanks or status narration, and mark judgement apart from verified fact. Check the whole comment for secrets and private details before posting, confirm GitHub returned its URL, and resolve a thread only after its reply posted.

Keep the PR the size the user's goal needs. Review loops grow a PR one cheap-looking fix at a time. Fix real bugs in the intended case and decline the rest with a reason, listing them as follow-ups: unneeded tests, guards for edge cases that do not matter, extra compatibility, small performance costs. Prefer the fix that deletes or narrows code.

## Base branch and readiness

Watch for changes to the base and rebase when needed. `pr-wait` reports base commits that touch this PR's files and a BEHIND or DIRTY merge state; `watch_pull_request` reports only conflicts, so check for BEHIND yourself before calling the PR ready. If an overlapping PR makes this one obsolete, stop, report it, and ask before closing the PR unless closing was authorized.

The PR is ready when the required checks are green on the latest head, every comment is fixed or answered, and the branch is up to date and mergeable. Merge only when the user asked for the merge, directly or through land. Right before merging, run `git fetch` and re-read the PR; never merge when it is BEHIND or DIRTY, or when base commits that landed after the last green run touch its files. Rebase, push and wait for green again instead. Otherwise unwatch and report the PR ready.

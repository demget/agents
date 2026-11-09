---
name: land
description: >-
  Use when the user says "land it", "land this", "full send" or invokes /land: they are not watching and want the change taken all the way to a merged PR. Proves the change, gets the council's sign-off, files the PR with the pr skill, babysits CI and review, and merges once the gate passes.
---

# Land

A request to land the change ("land it", "full send") means the user is not watching this thread: your updates and final message go unread until long after you stop. You own the work from its current state to a merged PR. Without such a clear request, do not assume this autonomy.

## What the request grants

- **Committing, pushing and opening a PR** for this change. If you are on the default branch, the request is also the ask to create a branch for it, since a PR needs one; otherwise stay on the current branch.
- **Rebasing that branch and force-pushing it** with `--force-with-lease`. Never force-push any other branch.
- **Waiting on the PR's remote CI.** The request to land is the explicit request a "do not wait for or poll CI unless asked" rule waits for.
- **The test methods Proof needs, without asking first:** running the app or a dev server, browser automation, screenshots, simulators, devices, computer use. This removes only ask-first and leave-it-to-the-user steps; rules on how to test (the command, fixture or harness to use, how to run verification) still apply.
- **Merging** once the merge gate passes.

It never overrides:

- the repository's privacy, access and data-handling rules; use approved test data and evidence, and request review by an authorized person if those rules prevent sufficient verification;
- a rule that a human must work through, review or approve the change, such as an issue labelled `human required`; stop there and ask;
- production changes, releases, data deletion, changes outside the repository, or a harness approval prompt.

## Steps

1. **Finish the change.** The smallest change that meets the request: fix the case that happened, not every case that could. Follow the repository's `AGENTS.md`, including its issue-tracking steps.
2. **Prove it** (see Proof), then commit with the `commit` skill.
3. **Council review.** Run the `council` skill on the committed branch, for review only; this skill's merge gate decides the merge. Fix what holds up and run new rounds until all three members say `SAFE`.
4. **File the PR** with the `pr` skill, rebased onto the latest default branch. The proof goes in its Evidence section.
5. **Babysit it** with the `babysit` skill: fix CI failures and real review findings, proving each fix before you push it.
6. **Re-council a moved head.** The council must have said `SAFE` on the exact SHA you merge. If the head moved after step 3, run one more round on it; when the only change is a conflict-free rebase, say so in the brief.
7. **Merge** when the merge gate passes.
8. **Report** (see Report).

Stay active from step 1 to step 8. Ending the turn without something that will wake you stops the work, because nobody prompts you again. Council completions wake the thread; for the PR, use `babysit`'s watcher. If you stop before the merge, unwatch the PR first.

## Proof

Proof is evidence you observed yourself in this session: command output, a reproduction, a screenshot. Use the most direct proof the change allows:

- Reproduce the original failure, apply the fix, and watch the same reproduction pass.
- Run the repository's verification command the way its `AGENTS.md` says, such as `make verify` once in the foreground.
- Add the regression test the repository asks for: one that fails without the fix, in the runner its checks already use.
- For UI and runtime behaviour, run the app and observe the change; green mocked tests do not prove the experience works. Capture the Before and After the `pr` skill requires.

If you cannot find a way to prove a change, you do not have full confidence: ask the user.

## Merge gate

All of these hold on the latest head:

- Your proof covers every change in the diff.
- All three council members said `SAFE` on this SHA.
- Required checks are green; when the base requires none, every check that ran is green. A skipped or unavailable check is not a pass.
- Every review comment is fixed or answered with a written reason, and no human review still requests changes.
- The branch is up to date with its base and GitHub reports it mergeable (`mergeStateStatus` is `CLEAN`).
- No repository rule still waits on a human.

Run `git fetch` and re-read the PR right before merging. Merge in the repository's style, taken from its allowed methods and recent history: when merged PRs land on the default branch as one `<title> (#<n>)` commit, that is `gh pr merge <n> --squash`. Never use `--admin` or any other bypass.

## Asking the user

A question in a normal message goes unseen and the thread looks finished. Ask with the harness's question tool (`AskUserQuestion` in Claude Code, `request_user_input` in Codex) so the thread shows it is waiting, and put everything in the question: the PR link, what blocks you, and the options with your recommendation first. Unwatch the PR before asking.

Ask only when you cannot continue alone:

- You cannot prove the change.
- The merge gate cannot pass and you cannot fix that yourself.
- The council is still split after three rounds, or a member keeps failing.
- The next step is outside the grant above.
- The goal is ambiguous in a way that changes the result.
- Another PR makes this one obsolete.

Decide everything else with sensible defaults and list those decisions in the report. If no question tool exists or it returns no answer, take the safe path: leave the PR open and unmerged, and start your final message with the question.

## Report

Lead with the outcome: merged or not, the PR link and the merge commit. Then the proof, each council member's final verdict, what review and CI changed, and every decision you made for the user.

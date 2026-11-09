---
name: council
description: >-
  Use when the user wants a pull request or branch judged by a council of other models before it lands: "consult the council", "ask the council if this is safe", "council review", "merge it once they're happy", "get Opus, Sol and Astra to sign off", or /council. Runs Opus 5.5, GPT-6.1 Sol and GPT-6 Astra as read-only reviewers through T3's delegate_task and merges only when all three say it is safe.
---

# Council review before merge

Three models review the same change independently. Each one only reads and reports; you weigh their findings, make the fixes, and merge once every member says the current head is safe. The value is independent disagreement, so the members must stay distinct and none may be swapped out silently.

## Scope

"Consult the council" authorizes the review and fixes the PR needs. A request that also says to merge ("merge it once they're happy") authorizes the merge once the council approves. Without that, report the verdicts and stop. The council never replaces the repository's own gates: its required checks, verification command and review rules still apply.

## Members

Check `orchestrator_capabilities` first. If a member's provider or model is missing, tell the user and stop rather than substituting another model.

| Member | `providerInstanceId` | `model` | `options` |
|---|---|---|---|
| Opus | `claudeAgent` | `claude-opus-5-5` | `{"effort": "xhigh", "fastMode": false}` |
| Astra | `codex` | `gpt-6-astra` | `{"reasoningEffort": "high", "serviceTier": "priority"}` |
| Sol | `codex` | `gpt-6.1-sol` | `{"reasoningEffort": "max", "serviceTier": "priority"}` |

## Write the brief

Before launching, read the full diff against its base and work out what could go wrong with this specific change. The brief is identical for all three members and contains:

- the PR URL, base branch and head SHA (`gh pr view <n> --json url,baseRefName,headRefOid`), or the branch and commit for an unpushed change;
- what the change is meant to do, in two or three sentences;
- the concrete risks to check, as specific questions rather than "look for bugs" (for example: can a batch be lost without the loss being logged; how much load do the retries add if the downstream service is down; are the retry code and its tests correct);
- **the read-only rule:** "Do not modify anything. No file edits, commits, pushes, PR comments, reviews, approvals or merges. You may read files and run read-only commands such as `git`, `gh pr view`, `gh pr diff` and searches.";
- the reply format: the first line is exactly `VERDICT: SAFE` or `VERDICT: CHANGES NEEDED`, followed by each blocking finding with `file:line`, the concrete failure scenario and the smallest fix, then any non-blocking notes under their own heading.

## Run a round

Launch all three in the same turn with `delegate_task`: `mode: "async"`, `role: "review"`, the member's `target` from the table, the title `Council: PR #<n> safety (<Member>)`, and `clientRequestId: "council-<pr>-r<round>-<member>"`. Leave `isolation` and `runtimeMode` unset; the read-only rule in the brief is what keeps members from changing the shared checkout.

Then tell the user in a few lines that the council is reviewing, which models at which effort, and the risks they are checking, and end the turn. Each member's completion wakes the thread; do not poll.

## Weigh the verdicts

- **All three `SAFE` on the current head SHA:** the council approves.
- **A blocking finding:** check it yourself against the code. If it holds, fix only what the PR needs to be safe and keep unrelated improvements out. Push, then run a new round with all three members on the new head.
- **A finding you think is wrong:** do not drop it. Put your rebuttal, with evidence, into the next round and let the member concede or hold its position.
- **Each new round** is a fresh `delegate_task` per member with a new `clientRequestId`. Its prompt carries the original brief, the new head SHA, every prior finding, your response to each, and any objection still open. Never continue a review by messaging an old child thread.
- **A member errors, times out or never returns a verdict line:** the council has not approved. Report it and ask the user whether to retry that member or proceed without it.
- **Still split after three rounds:** stop and lay out the disagreement for the user to decide.

## Merge

Only when every member approved the exact SHA you are about to merge:

1. Confirm the head has not moved since approval (`gh pr view <n> --json headRefOid,mergeable,mergeStateStatus`) and that the repository's required checks and rules allow the merge.
2. Merge in the repository's established style, found from its docs or its `main` history (for example `gh pr merge <n> --squash`).
3. Report the outcome first: merged or not, then one line per member with its final verdict, and what was fixed along the way.

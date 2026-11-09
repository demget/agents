---
name: score-hill-climb
description: >-
  Use when the user wants a result pushed up against a score until it clears a bar: "hill climb this", "keep going until the council gives it 9/10", "iterate until every judge rates every category 9.5", "make the UI score higher than Claude Code and Codex", "get the eval to a perfect score, then cut the descriptions to a third and keep it perfect", "send 4x less data with no regressions", or /score-hill-climb. Picks or builds the score, measures a baseline, then changes, measures and keeps or reverts until the bar clears, using a program when one can measure the goal and a panel of model judges when only taste can.
---

# Score hill climb

Turn the goal into a number, then repeat: change one thing, measure, keep it if the number rose and nothing else broke, revert it if not. An agent will push any score it can see upward, so most of the skill is choosing a score that rises only when the work truly improves, and guarding everything the score does not see.

## Scope

The request sets the goal and the bar ("9 out of 10 from every judge", "a third the size with a perfect score"). If it gives no bar, ask once with the harness's question tool and recommend one. The climb authorizes the edits, measurements and judge rounds it needs; commit each kept step on the current branch with the `commit` skill. It never authorizes branches, PRs, merges or releases the user did not ask for, and the repository's verification, privacy, access and data-handling rules bind the climb and every judge in it.

## 1. Choose the score

**Prefer a program.** A test count, eval cases passed, bytes sent to the client, tokens of context, latency, bundle size. It is cheap, repeatable and cannot be talked into a higher number. Use judges only when no program can measure the goal, as with visual design or the tone of copy.

**Build the eval from real failures.** When no measure exists, collect the times the system actually did the wrong thing (logs, past threads, issues, traces), group them into categories, and make each case one observable pass or fail. Run it on the current code first: it must fail the cases it was built from, or it measures nothing. Add it to the repository's test runner in the same change, so the climb leaves regression coverage behind instead of a one-off script.

**Name the guards.** List what must not get worse while the score climbs: the test suite, the repository's verification command, an eval already at its best, the other surfaces a change reaches. Check them on every kept step. A score with no guard gets gamed, such as tool descriptions cut until the token count drops and the model stops calling the tools.

## 2. Measure the baseline

Measure the starting point before changing anything and start a ledger, kept in the thread and in the final report:

| Round | Change | Score | Guards | Kept |
|---|---|---|---|---|
| 0 | baseline | 66/85 | green | — |

When the measure is noisy (timings, model-run evals), run it several times and use the median, and record the spread so you can tell a gain from noise.

## 3. Climb

- **One idea per round.** Make the smallest change that tests it, measure, and keep it only when the score rose and the guards held. Scores do fall: revert to the best commit rather than building on a regression.
- **Read the failures, not just the number.** Each round, look at which cases or categories are still below the bar and aim the next change at the lowest one.
- **Stalled for three rounds:** step back and rethink the approach, or report where it stopped and why.

**Two-phase climbs.** When the goal has a primary score and a secondary one ("perfect eval, then a third the size"), climb the primary to its bar first, commit, and confirm it holds for every model or configuration that matters. Then climb the secondary with the primary as a guard, so each cut is kept only while the primary stays at its bar.

## Judge panel

When taste is the score, the judges are the members in the `council` skill's table, launched the way that skill launches them: `delegate_task` in async mode with the review role, read-only, and a fresh delegate with a new `clientRequestId` (`climb-<slug>-r<round>-<member>`) every round. Never continue a round by messaging an old child thread. Completions wake the thread; do not poll.

**Fix the scorecard before round 1.** Agree on the categories with the user; for UI, for example: hierarchy, typography, colour and contrast, spacing and layout, consistency, iconography, clarity. Each judge scores every category from 1 to 10 with one decimal and names the changes that would most raise its lowest category. The bar is cleared only when every judge rates every category at or above it in the same round.

**Judge against references, never alone.** A design judged on its own looks fine; the same PR that one judge rated 9/10 in isolation scored 7.4 once it was set beside Claude Code and Codex. Each round, have every judge score the baseline, the current state and one or more references (competing products, a design the user admires) in the same pass. References also drift upward as the candidate improves, so watch the gap between them as well as the absolute number.

**Keep judges blind to the bar.** Never tell a judge the target score, earlier scores or which option is the new work. Label the options neutrally (A, B, C) and shuffle them each round. Knowing the goal can pull a judge's scores toward it.

**Give every judge the same evidence.** Capture a fixed list of relevant screens and states (such as supported themes, empty and populated states, and narrow and wide layouts) fresh from the running app each round, and equivalent states for every reference, then pass the file paths in the brief. Inspect the captures before sharing them. Use representative test data, follow the repository's privacy and access rules, and share evidence only with authorized reviewers. If restrictions prevent a fair comparison, report the limitation.

**Gate expensive judges.** Start with the fastest strong judge alone. Add the next one once the first clears the bar, and the slowest only for confirming rounds. Never let a slow judge hold up the rounds the others can run.

**Weigh findings.** Judges are not deterministic: the same screenshot shown three times gets three scores. A finding two judges share is real; a lone judge's quirk that the others contradict is noted, not chased. Consensus of distinct models at a high bar is the signal, not any single number.

**Take the user's taste as a constraint.** When the user steers mid-climb ("it has gone too grayscale, bring some colour back"), add that sentence to every later brief as a requirement, not as a score. When the user cannot see what changed, make before-and-after captures with the changes marked and described.

## Raising the bar

Each step up costs far more than the last: reaching 9 took three rounds, 9.5 took ten more. When the bar clears, stop and report; raise it only when the user asks. A new bar starts with fresh judges and, if the thread is long, a fresh thread, so earlier praise does not anchor the scores. The commit that cleared the previous bar stays recorded in the ledger, so a higher-bar attempt can be dropped without losing it.

## Report

Lead with the outcome: whether the bar cleared, and the final score against the baseline. Then the ledger, the changes that moved the score most, the state of every guard, where the eval lives if you built one, and the rounds and agent time the climb used.

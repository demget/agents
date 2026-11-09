---
name: pr
description: Use when the user asks to file, open, or create a PR ("file a PR"), prepare a PR with screenshots, add missing screenshots or recordings to a PR, or invokes /pr, and for land's file-PR step. Carries visual evidence and manual test results into the PR body.
metadata:
  credits:
    - skill: pr
      author: Matt Pocock
      url: "https://github.com/mattpocock/skills/blob/main/skills/engineering/pr/SKILL.md"
      license: MIT
    - skill: show-me
      author: Dex Horthy
      organisation: HumanLayer
      url: "https://github.com/humanlayer/skills/blob/main/plugins/show-me/skills/show-me/SKILL.md"
---

# File a pull request with evidence

The coding agent prepares and submits the complete PR body, including uploaded evidence and the manual checks it ran. A chat handoff or commit message is not a substitute: a GUI's separate PR writer may receive only commit subjects and a truncated diff.

## Scope

An instruction to file a PR authorizes preparing and submitting it; carry out that request without asking again. A request only to prepare screenshots or a draft body does not authorize opening a PR. Creating or changing this skill does not authorize opening a PR either. Honor the repository's branch, commit, privacy, access and testing rules. Do not merge unless asked.

## Prepare

- Confirm the target repository, head and base branches, and look for an existing PR for that head. Update the existing PR when appropriate instead of creating a duplicate. Use the commit skill when committing or pushing; preserve unrelated work.
- Read the repository's PR template and review the full branch diff against the intended base. Keep the PR to the requested concern.
- Run the required checks for the changed surfaces. Distinguish passed, failed, skipped and unavailable evidence; a result absent from your context does not mean the check was never run.

## Title

The title usually becomes the commit message, so follow the repository's title convention; recently merged PRs show it. Say what changed for the person affected and why it matters, not which mechanism moved.

| | Title |
|---|---|
| Bad | `perf(server): negotiate permessage-deflate on the websocket` |
| Good | `perf(server): cut websocket frame size by 70% with gzip` |
| Bad | `fix(server): parse CLI version and update preflight` |
| Good | `fix(server): stop false version-drift errors on remote hosts` |

## Body

Use this structure unless the repository's template asks for another:

```markdown
## Summary

<the problem in the user's words, then the fix in a sentence>

## Evidence

### <state>

<what to notice>

| Before | After |
|---|---|
| <image> | <image> |

- **Before:** <output or the regression test failing>
  **After:** <output or the same test passing>

## Merge Danger

**Door:** <one-way or two-way>

<optional: why>

**Blast Radius:** <one word>

<optional: ramifications of merging>
```

Skip preambles and keep prose brief. Use the domain language from the repository's `GLOSSARY.md` when it has one. Omit any section or part with nothing to report, such as screenshots for a change with no visible surface, instead of filling it with a line saying there is nothing; this overrides a template that asks to keep the section.

### Summary

Open with the problem as a player, operator or developer meets it, then the fix in a sentence or two. Write for a reader who never saw the conversation behind the change: never "you asked", "as discussed", review rounds or rejected drafts, and link the issue that records a decision. Never lead with an inventory of what the implementation touched; the diff already shows that. Write it in prose: no diagrams, trees, pseudocode or diff sketches; a flow chart pair belongs in Evidence.

Bad opening:

> Refactored the preferences hydration path and the form initialization lifecycle to apply the persisted locale value.

Good opening:

> The form ignored the user's saved language. It now opens in the selected language.

### Evidence

Concrete proof that the change works, as a Before and an After. Screenshots are S-tier for a visible change; execution evidence is A-tier. Show both when both apply.

For a visible change, present each changed state as a labelled pair: a `###` heading naming the state, one caption saying what to notice, then a table whose columns are Before and After, one image per cell. A design reference may be a third column; it never stands in for Before or After. Leave no bare image rows, shared captions or unlabelled sides. Capture the pairs as in Capture and upload.

For behaviour, write the Before and the After in prose: what happened before and what happens now, then name the regression test and say it fails without the fix. Quote real output only when its exact text is the evidence, such as an error message. No pseudocode, test walkthroughs or code blocks that restate the test.

When the change reshapes a flow that a reader would otherwise rebuild from prose, such as the order or overlap of requests, the steps a person passes through, or the states a record moves between and what moves it, show the flow as a Before and an After chart. Present it like a screenshot pair: a `###` heading naming the flow, one caption saying what to notice, then the two images side by side. A change that keeps the flow's shape, such as a new value or wording, needs no chart.

Also report what the PR's CI run cannot show: manual checks against the running product, device or browser reproductions, and required checks skipped on purpose, with the reason. That one regression test is the only automated check to show; never inventory the suite CI already runs, since GitHub records it on the PR.

### Merge Danger

**Door** says whether the change can be walked back. A two-way door is cheap to roll back by reverting. A one-way door cannot be walked back: a data migration or deletion, a published API or schema, a message sent to users, a release. Say what makes it one-way.

**Blast Radius** is the scope of what merging could affect, in one word, such as `none`, `local`, `module`, `app` or `consumers`. Follow it with the ramifications worth checking, such as layout shift, breakage for consumers, mobile layouts or another team's workflow.

### A good whole body

Under `fix(release): skip scripts during deploy installs`:

````markdown
## Summary

Releases were blocked: the deploy's build cache kept hitting its 100-file limit. The deploy installs twice, and each install ran the root `prepare` script, which left a backup in the cache. Installs now skip scripts.

## Evidence

- **Before:** the third deploy on one cache failed with `cache exceeds 100 files`.
  **After:** five deploys in a row on one cache succeeded, and the file count stayed flat.

## Merge Danger

**Door:** two-way

**Blast Radius:** deploy

A package that needs its install script to build would now fail the deploy; none in the lockfile has one.
````

## Capture and upload

A visible change requires a Before and an After for every changed state. Take Before from the base branch and After from the branch head, in one scripted run with the same viewport, locale, data and fixtures, so the change is the only difference; a temporary worktree of the base serves both at once. For a new surface with no Before, say so and show the relevant finished states. Include internal and admin interfaces. Use a short recording when motion or interaction is the change. Cover affected clients, locales and themes as relevant, using the repository's harness and fixtures. Keep PR-only media outside tracked source.

Use representative test data for screenshots and recordings, and inspect each capture before uploading it. Follow the repository's privacy and access rules; exclude secrets and personal data, and use approved synthetic or redacted data where needed. Apply the same treatment to both sides of a Before and After pair. If restrictions prevent inspection or sufficient evidence, report the limitation and request review by an authorized person.

Upload the sides of a pair as separate images rather than one composite. After shows the head commit. When a later push changes what a shot shows, retake the pair and replace it; never keep a stale shot with a note that it is stale.

Use the repository's approved upload destination. For GitHub, run the bundled helper from the target checkout; it uses that repository and the authenticated `gh` account:

```bash
bash ~/.agents/skills/pr/scripts/attach.sh /absolute/path/before.png /absolute/path/after.png
```

Draw a flow chart pair with the repository's own flow chart skill when it has one. Otherwise write two Mermaid files and render them with the bundled helper, which writes an SVG and a 2x PNG beside each file:

```bash
node ~/.agents/skills/pr/scripts/chart.mjs /absolute/path/before.mmd /absolute/path/after.mmd
```

Label each box and arrow in the reader's words, such as "Load the account" or "the payment fails", never a function or endpoint name. Draw both sides at the same level of detail, so the change is the only difference, and keep each to about 15 boxes: leave out branches the change does not touch, and say so in the caption. Mark the steps the caption is about with `class <ids> key`, such as the waits on the common path numbered in order, and the start and end with `class <ids> terminal`. Open both PNGs to check them before uploading the pair.

The helper prints Markdown image embeds and standalone video URLs. Preserve the returned URLs exactly. The GitHub upload endpoint is undocumented; if it fails, report the failure and keep the prepared body and local evidence. Do not silently switch private material to a public host or submit a visible-change PR with missing required evidence. A configured public upload service is usable only where the user and repository permit that destination.

## Submit and verify

Write the complete body to a temporary Markdown file, following the repository template or the Body structure above. Include the actual upload URLs, captions, manual test outcomes and material limitations. Use a normal PR unless the user requests a draft.

Create it with `gh pr create --base <base> --head <head> --title <title> --body-file <file>`, or use `gh pr edit <number> --body-file <file>` for an existing PR. Preserve unrelated body sections when adding evidence to someone else's body. When revising your own after the evidence or outcomes changed, rebuild the whole body instead of patching sections in: patched bodies accumulate stale captions, contradictory limits and sections outside the structure. If creation times out, look for the PR before retrying.

Read the published result with `gh pr view <number> --json url,body,baseRefName,headRefName`. Check that it targets the intended branches, that every changed state has its Before and After side by side from the named commits, and that every intended attachment URL, caption and manual test outcome survived. Correct a missing section before declaring the handoff complete. Report the PR link and any remaining limitations.

If the user also asks to babysit, continue with the `babysit` skill; babysitting alone does not authorize merging.

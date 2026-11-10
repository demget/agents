# agents

My instructions, skills and Claude Code settings, shared by every machine I work on and by both Claude Code and Codex.

| Path | Is |
|---|---|
| `AGENTS.md` | My global instructions. Claude imports it from `~/.claude/CLAUDE.md`; Codex gets a generated copy at `~/.codex/AGENTS.md`. |
| `skills/` | Skills for both tools. Codex reads this directory itself; Claude gets a link per skill in `~/.claude/skills`. |
| `claude/` | Claude Code only: `settings.json`, its hooks and Claude-only skills. `hooks/allow-tmp-rm.py` approves, in bypass mode, the prompt Claude Code raises before an `rm` of a `/tmp` directory the shell is inside. |
| `install.sh` | Links everything into place. Safe to re-run. |
| `sync.sh` | Run by hand: pulls from GitHub, pushes the commits you made and re-runs `install.sh`. Never commits. |

## A new machine

```sh
gh repo clone demget/agents ~/.agents && ~/.agents/install.sh
```

Files `install.sh` replaces go to `~/.claude/backups/agents-<time>/`. Sign-ins never sync: log in to Claude, Codex and `gh` on each machine.

## Staying in sync

Nothing syncs on its own: this repository is public. To publish a change, review `git diff`, commit only what should be public, then run `~/.agents/sync.sh --now` on that machine and on each other machine to pull it. `sync.sh` refuses to run while `~/.agents` has uncommitted or untracked changes, so nothing reaches GitHub without a commit you made.

A machine's own text in its generated instruction files lives in a marked block, `<!-- name: … -->` to `<!-- /name -->`, and survives `install.sh`. Keep hostnames, deployment details, credentials and private project instructions in local files, not in this repository.

If the remote history has been replaced, make a fresh clone after saving local work privately. Do not rebase or merge the old history into the new repository. `sync.sh` refuses unrelated or rewritten upstream history. A machine still running an older `sync.sh` (one that commits on its own or runs from a `SessionStart` hook) must have that hook removed and get a fresh clone before it syncs again.

## From tstack

`land` and `babysit` are adapted from [t3dotgg/tstack](https://github.com/t3dotgg/tstack) at `1085050` (`full-send` and `babysit-pr`); `babysit/scripts/pr-wait` is copied from it unchanged. Compare with upstream:

```sh
gh repo clone t3dotgg/tstack /tmp/tstack && git -C /tmp/tstack diff 1085050 -- skills/full-send skills/babysit-pr
```

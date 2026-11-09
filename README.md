# agents

My instructions, skills and Claude Code settings, shared by every machine I work on and by both Claude Code and Codex.

| Path | Is |
|---|---|
| `AGENTS.md` | My global instructions. Claude imports it from `~/.claude/CLAUDE.md`; Codex gets a generated copy at `~/.codex/AGENTS.md`. |
| `skills/` | Skills for both tools. Codex reads this directory itself; Claude gets a link per skill in `~/.claude/skills`. |
| `claude/` | Claude Code only: `settings.json`, its hooks and Claude-only skills. `hooks/allow-tmp-rm.py` approves, in bypass mode, the prompt Claude Code raises before an `rm` of a `/tmp` directory the shell is inside. |
| `install.sh` | Links everything into place. Safe to re-run. |
| `sync.sh` | Commits local edits, rebases onto GitHub, pushes and re-runs `install.sh`. |

## A new machine

```sh
gh repo clone demget/agents ~/.agents && ~/.agents/install.sh
```

Files `install.sh` replaces go to `~/.claude/backups/agents-<time>/`. Sign-ins never sync: log in to Claude, Codex and `gh` on each machine.

## Staying in sync

Claude Code's `SessionStart` hook runs `sync.sh`, which syncs in the background at most every 10 minutes, so an edit made on one machine reaches the others by their next session. Tracked edits are committed as `chore(sync): update shared configuration`; new files must be reviewed and staged manually. Commit by hand first when you want a better message. When a sync fails (a conflict, a rejected push), the next session's agent is told why; fix it, then run `~/.agents/sync.sh --now`.

A machine's own text in its generated instruction files lives in a marked block, `<!-- name: … -->` to `<!-- /name -->`, and survives `install.sh`. Keep hostnames, deployment details, credentials and private project instructions in local files, not in this repository.

If the remote history has been replaced, stop automatic sync on every existing machine and make a fresh clone after saving local work privately. Do not rebase or merge the old history into the new repository. The updated sync script refuses unrelated or rewritten upstream history; old installed copies must still be replaced manually.

## From tstack

`land` and `babysit` are adapted from [t3dotgg/tstack](https://github.com/t3dotgg/tstack) at `1085050` (`full-send` and `babysit-pr`); `babysit/scripts/pr-wait` is copied from it unchanged. Compare with upstream:

```sh
gh repo clone t3dotgg/tstack /tmp/tstack && git -C /tmp/tstack diff 1085050 -- skills/full-send skills/babysit-pr
```

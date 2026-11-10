#!/bin/sh
# Syncs ~/.agents with GitHub, only when you ask: `~/.agents/sync.sh --now`.
# It never commits. Review and commit what should be public first; it refuses to run with
# uncommitted or untracked changes, then pulls, pushes your commits through the pre-push privacy
# check and re-runs install.sh.
set -u
fail() { echo "sync.sh: $1" >&2; exit 1; }

# A leftover SessionStart hook calls this without --now; do nothing then.
[ "${1:-}" = --now ] || { echo "sync.sh: not syncing; run ~/.agents/sync.sh --now to sync" >&2; exit 0; }

cd "$HOME/.agents" || exit 1
if [ -n "$(git status --porcelain)" ]; then
  git status --short >&2
  fail "uncommitted changes in ~/.agents; review them, commit only what should be public, then sync again"
fi
git config core.hooksPath hooks  # the pre-push hook scans every outgoing commit
upstream=$(git rev-parse --abbrev-ref '@{upstream}') || fail "no upstream configured; configure it manually"
previous=$(git rev-parse "$upstream") || fail "cannot read upstream"
git fetch -q || fail "fetch failed"
git merge-base HEAD "$upstream" >/dev/null 2>&1 || fail "remote history was replaced; save local work privately and make a fresh clone, do not merge or rebase this copy"
git merge-base --is-ancestor "$previous" "$upstream" || fail "upstream history was rewritten; inspect it manually before syncing"
git rebase -q "$upstream" || { git rebase --abort 2>/dev/null; fail "local commits conflict with origin; rebase ~/.agents by hand"; }
if [ -n "$(git rev-list "$upstream..HEAD")" ]; then
  echo "Pushing:"; git log --oneline "$upstream..HEAD"
  git push -q || fail "push to origin failed"
fi
./install.sh || fail "install.sh failed"

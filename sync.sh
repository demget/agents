#!/bin/sh
# Keeps ~/.agents in step with GitHub: commits local edits, rebases onto origin, pushes, rewires.
# Claude Code runs it at every session start; it syncs in the background at most every 10 minutes.
# Run `~/.agents/sync.sh --now` to sync in the foreground.
set -u
A="$HOME/.agents" G="$HOME/.agents/.git"

if [ "${1:-}" != --now ]; then
  [ ! -f "$G/sync-error" ] || echo "~/.agents is not syncing: $(cat "$G/sync-error"). Tell the user; after fixing it, run ~/.agents/sync.sh --now."
  [ -z "$(find "$G/sync-stamp" -mmin -10 2>/dev/null)" ] || exit 0
  nohup "$0" --now </dev/null >"$G/sync.log" 2>&1 &
  exit 0
fi

find "$G/sync-lock" -maxdepth 0 -mmin +10 -exec rmdir {} \; 2>/dev/null
mkdir "$G/sync-lock" 2>/dev/null || exit 0
trap 'rmdir "$G/sync-lock"' EXIT
touch "$G/sync-stamp"
rm -f "$G/sync-error"
fail() { echo "$1" > "$G/sync-error"; echo "$1" >&2; exit 1; }

cd "$A" || exit 1
upstream=$(git rev-parse --abbrev-ref '@{upstream}') || fail "no upstream configured; configure it manually"
previous=$(git rev-parse "$upstream") || fail "cannot read upstream"
git fetch -q || fail "fetch failed"
git merge-base HEAD "$upstream" >/dev/null 2>&1 || fail "remote history was replaced; save local work privately and make a fresh clone, do not merge or rebase this copy"
git merge-base --is-ancestor "$previous" "$upstream" || fail "upstream history was rewritten; inspect it manually before syncing"
./install.sh || fail "install.sh failed, see ~/.agents/.git/sync.log"
git add -u || fail "staging tracked changes failed"
if ! git diff --cached --quiet; then
  git commit -qm "chore(sync): update shared configuration" || fail "commit failed"
fi
git rebase "$upstream" -q || { git rebase --abort 2>/dev/null; fail "local commits conflict with origin; rebase ~/.agents by hand"; }
git push -q || fail "push to origin failed"
./install.sh || fail "install.sh failed, see ~/.agents/.git/sync.log"

#!/usr/bin/env bash
# Upload evidence to the current repository's GitHub attachment store.
set -euo pipefail

[ $# -gt 0 ] || { echo "usage: attach.sh <file> [file...]" >&2; exit 2; }

for f in "$@"; do
  [ -f "$f" ] || { echo "no such file: $f" >&2; exit 1; }
done

slug=$(gh repo view --json nameWithOwner -q .nameWithOwner)
repo_id=$(gh api "repos/$slug" --jq .id)
token=$(gh auth token)

for f in "$@"; do
  name=$(basename "$f")
  mime=$(file --brief --mime-type "$f")
  query=$(jq -nr --arg name "$name" --arg mime "$mime" --arg repo "$repo_id" \
    '"name=\($name | @uri)&content_type=\($mime | @uri)&repository_id=\($repo | @uri)"')
  body=$(curl --fail-with-body -sS -X POST \
    "https://uploads.github.com/user-attachments/assets?${query}" \
    -H "Authorization: Bearer $token" -H "Accept: application/json" \
    --data-binary "@$f")
  url=$(printf '%s' "$body" | jq -er '.url | select(type == "string" and startswith("https://github.com/user-attachments/assets/"))') \
    || { echo "upload returned no GitHub attachment URL for $name" >&2; exit 1; }
  case "$mime" in
    image/*) printf '![Screenshot](%s)\n' "$url" ;;
    video/*) printf '%s\n' "$url" ;;
    *) printf '[Attachment](%s)\n' "$url" ;;
  esac
done

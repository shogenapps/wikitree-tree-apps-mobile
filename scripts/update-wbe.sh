#!/usr/bin/env bash
# Points shared/wbe.lock at the newest webview build on a WikiTree Browser Extension release, then
# fetches it. Commit the changed lock file; that commit is the review point for a WBE update.
#
#   scripts/update-wbe.sh                 the release named in the lock now (e.g. test/development)
#   scripts/update-wbe.sh stable          or preview, or another release tag
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
lock="$root/shared/wbe.lock"
field() { sed -nE "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p" "$lock" | head -n 1; }
sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }

repo="$(field repo)"
tag="${1:-$(field tag)}"
api="https://api.github.com/repos/$repo/releases/tags/$tag"
asset="$(curl -fsSL "$api" | grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]*-webview\.zip"' | head -n 1 | sed -E 's/.*"([^"]*)"$/\1/')"
[ -n "$asset" ] || { echo "No *-webview.zip on the $tag release of $repo." >&2; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
curl -fsSL --retry 3 -o "$tmp/wbe.zip" "https://github.com/$repo/releases/download/${tag//\//%2F}/$asset"
sum="$(sha256 "$tmp/wbe.zip")"

cat > "$lock" <<JSON
{
  "repo": "$repo",
  "tag": "$tag",
  "asset": "$asset",
  "sha256": "$sum"
}
JSON
echo "shared/wbe.lock now names $asset ($sum)"
"$root/scripts/fetch-wbe.sh"

#!/usr/bin/env bash
# Puts the WikiTree Browser Extension's webview build in shared/wbe/, from the release asset named
# in shared/wbe.lock, after checking its SHA-256. The Android and iOS builds run this; it does
# nothing when shared/wbe/ already holds that exact build.
#
# WBE's preview release is replaced on every WBE release run, so the locked asset can vanish. Then
# the newest *-webview.zip on the same release is taken instead, with a warning (its SHA-256 can't
# be checked against the lock), so the build still works. Run scripts/update-wbe.sh to lock it.
# GH_TOKEN or GITHUB_TOKEN, if set, is used for the GitHub API call that finds it.
#
#   WBE_ZIP=/path/to/dist-webview.zip scripts/fetch-wbe.sh   use a local zip instead (for testing;
#                                                             its SHA-256 is not checked)
# See docs/wbe.md.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
lock="$root/shared/wbe.lock"
dest="$root/shared/wbe"

field() { sed -nE "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p" "$lock" | head -n 1; }
sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }

repo="$(field repo)"; tag="$(field tag)"; asset="$(field asset)"; want="$(field sha256)"
stamp="${WBE_ZIP:+local:$WBE_ZIP}"; stamp="${stamp:-$want}"

if [ -f "$dest/.source" ] && [ "$(cat "$dest/.source")" = "$stamp" ] && [ -f "$dest/webview.json" ]; then
  exit 0
fi

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
if [ -n "${WBE_ZIP:-}" ]; then
  cp "$WBE_ZIP" "$tmp/wbe.zip"
else
  # The tag can contain a slash (test/development), which must be encoded in the download URL.
  url="https://github.com/$repo/releases/download/${tag//\//%2F}/$asset"
  echo "Downloading $url"
  if curl -fsSL --retry 3 -o "$tmp/wbe.zip" "$url"; then
    got="$(sha256 "$tmp/wbe.zip")"
  else
    # The locked build is gone: take the newest webview build on the same release.
    echo "Could not download $asset; looking for the newest *-webview.zip on the $tag release." >&2
    token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
    api="https://api.github.com/repos/$repo/releases/tags/${tag//\//%2F}"
    latest="$(curl -fsSL --retry 3 ${token:+-H "Authorization: Bearer $token"} "$api" |
      grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]*-webview\.zip"' | head -n 1 | sed -E 's/.*"([^"]*)"$/\1/')" || latest=""
    [ -n "$latest" ] || {
      echo "No *-webview.zip found on the $tag release of $repo either." >&2
      exit 1
    }
    curl -fsSL --retry 3 -o "$tmp/wbe.zip" "https://github.com/$repo/releases/download/${tag//\//%2F}/$latest" || {
      echo "Could not download $latest either." >&2
      exit 1
    }
    got="$(sha256 "$tmp/wbe.zip")"
    echo "warning: using $latest ($got) in place of the locked $asset." >&2
    echo "warning: run scripts/update-wbe.sh to lock it, so later builds check its SHA-256." >&2
    want="$got"
    stamp="latest:$got"
  fi
  if [ "$got" != "$want" ]; then
    echo "SHA-256 of $asset is $got, but shared/wbe.lock expects $want." >&2
    echo "The release changed: run scripts/update-wbe.sh to take the new build on purpose." >&2
    exit 1
  fi
fi

mkdir -p "$tmp/x"
unzip -q "$tmp/wbe.zip" -d "$tmp/x"
# Accept a zip with the files at the top or inside one folder (dist-webview/).
src="$tmp/x"
[ -f "$src/webview.json" ] || src="$(dirname "$(find "$tmp/x" -name webview.json -maxdepth 2 | head -n 1)")"
[ -f "$src/webview.json" ] || { echo "No webview.json in the WBE zip." >&2; exit 1; }

rm -rf "$dest"
mkdir -p "$dest"
cp -R "$src/." "$dest/"
echo "$stamp" > "$dest/.source"
echo "WBE $(sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' "$dest/webview.json" | head -n 1) is in shared/wbe/"

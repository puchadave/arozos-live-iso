#!/usr/bin/env bash
set -euo pipefail
BASE=$(cd "$(dirname "$0")/.." && pwd)
. "$BASE/upstream.env"
OUT=${1:-"$BASE/output/apk-repo/$ARCH"}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"
REPOS="$TMP/repositories"
cat > "$REPOS" <<REPO
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_RELEASE}/main
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_RELEASE}/community
@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing
REPO
cat "$BASE/requirements/core.txt" "$BASE/requirements/installer.txt" "$BASE/requirements/rescue.txt" | grep -Ev '^($|#)' | sort -u > "$TMP/requirements.txt"
mkdir -p "$TMP/apks"
apk fetch --repositories-file "$REPOS" --recursive --output "$TMP/apks" $(cat "$TMP/requirements.txt")
apk index -o "$OUT/APKINDEX.tar.gz" "$TMP"/apks/*.apk
for apkfile in "$TMP"/apks/*.apk; do
  [ -f "$apkfile" ] || continue
  basename "$apkfile"
done | sort > "$OUT/packages.list"
cp "$TMP/requirements.txt" "$OUT/requirements.txt"
if [ -n "${APK_SIGNING_KEY:-}" ]; then
  abuild-sign -k "$APK_SIGNING_KEY" "$OUT/APKINDEX.tar.gz"
fi
echo "Curated index generated at $OUT; package payloads intentionally discarded."

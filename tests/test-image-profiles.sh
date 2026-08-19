#!/bin/sh
set -eu

profiles="live installer rescue pxe-boot pxe-se mega"

for profile in $profiles; do
    file="profiles/${profile}.conf"
    [ -f "$file" ] || { echo "missing profile: $file" >&2; exit 1; }
    grep -q '^IMAGE_ID=' "$file" || { echo "$file missing IMAGE_ID" >&2; exit 1; }
    grep -q '^MODE=' "$file" || { echo "$file missing MODE" >&2; exit 1; }
    grep -q '^VOLUME_ID=' "$file" || { echo "$file missing VOLUME_ID" >&2; exit 1; }
    grep -q '^ARCHES=' "$file" || { echo "$file missing ARCHES" >&2; exit 1; }
done

grep -q '^MODE=live$' profiles/live.conf
grep -q '^MODE=installer$' profiles/installer.conf
grep -q '^MODE=rescue$' profiles/rescue.conf
grep -q '^MODE=pxe-boot$' profiles/pxe-boot.conf
grep -q '^MODE=pxe-se$' profiles/pxe-se.conf
grep -q '^MODE=mega$' profiles/mega.conf

grep -q 'x86_64' profiles/mega.conf
grep -q 'aarch64' profiles/mega.conf

echo "image profile contract: ok"

#!/bin/sh
set -eu

INIT=initramfs/arozos-live-init
[ -f "$INIT" ]

grep -q 'aroz.source=' "$INIT"
grep -q 'aroz.root_url=' "$INIT"
grep -q 'aroz.volume=' "$INIT"
grep -q 'ROOT_SOURCE=iso' "$INIT"
grep -q 'ROOT_SOURCE.*http\|"http"' "$INIT"
grep -q 'wget' "$INIT"
grep -q 'rootfs.squashfs' "$INIT"

# Local ISO mode must continue to mount the immutable root read-only.
grep -q 'mount -t squashfs' "$INIT"
grep -q 'overlay' "$INIT"
grep -q 'switch_root' "$INIT"

echo "initramfs source contract: ok"

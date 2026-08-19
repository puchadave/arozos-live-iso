#!/bin/sh
set -eu

AR=rootfs/etc/init.d/arozos
NET=rootfs/etc/init.d/arozos-net
PXE=rootfs/etc/init.d/arozos-pxe-se

for f in "$AR" "$NET" "$PXE"; do
    [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
done

grep -q '/run/arozos-mode' "$AR"
grep -q '/run/arozos-mode' "$NET"
grep -q '/run/arozos-mode' "$PXE"

grep -Eq 'live|debug|pxe-se' "$AR"
grep -Eq 'live|debug|pxe-se' "$NET"
grep -q 'pxe-se' "$PXE"

echo "mode-gated services: ok"

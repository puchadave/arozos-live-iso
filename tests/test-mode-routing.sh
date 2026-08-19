#!/bin/sh
set -eu

MODE_SCRIPT=rootfs/usr/local/sbin/arozos-mode-init
INIT=rootfs/etc/init.d/arozos-mode
MEGA=boot/grub/mega.cfg

[ -f "$MODE_SCRIPT" ] || { echo "missing $MODE_SCRIPT" >&2; exit 1; }
[ -f "$INIT" ] || { echo "missing $INIT" >&2; exit 1; }
[ -f "$MEGA" ] || { echo "missing $MEGA" >&2; exit 1; }

for mode in live installer rescue alpine pxe-se debug; do
    grep -q "aroz.mode=$mode" "$MEGA" || { echo "mega menu missing mode $mode" >&2; exit 1; }
done

grep -q 'aroz.mode=' "$MODE_SCRIPT"
grep -q 'pxe-se' "$MODE_SCRIPT"
grep -q 'arozos' "$MODE_SCRIPT"

echo "boot mode routing contract: ok"

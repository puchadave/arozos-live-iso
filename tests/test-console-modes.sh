#!/bin/sh
set -eu

CONSOLE=rootfs/usr/local/sbin/arozos-console
INITTAB=rootfs/etc/inittab

[ -f "$CONSOLE" ] || { echo "missing $CONSOLE" >&2; exit 1; }
[ -f "$INITTAB" ] || { echo "missing $INITTAB" >&2; exit 1; }

grep -q '/run/arozos-mode' "$CONSOLE"
grep -q 'installer' "$CONSOLE"
grep -q 'rescue' "$CONSOLE"
grep -q 'alpine' "$CONSOLE"
grep -q '/bin/sh' "$CONSOLE"
grep -q 'arozos-console' "$INITTAB"
grep -q 'openrc sysinit' "$INITTAB"
grep -q 'openrc shutdown' "$INITTAB"

echo "physical console mode contract: ok"

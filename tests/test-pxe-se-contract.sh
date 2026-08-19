#!/bin/sh
set -eu

REQ=requirements/pxe-se.txt
CONF=rootfs/etc/dnsmasq.d/arozos-pxe-se.conf
INIT=rootfs/etc/init.d/arozos-pxe-se
MENU=rootfs/var/lib/arozos-pxe-se/boot.ipxe

[ -f "$REQ" ] || { echo "missing $REQ" >&2; exit 1; }
[ -f "$CONF" ] || { echo "missing $CONF" >&2; exit 1; }
[ -f "$INIT" ] || { echo "missing $INIT" >&2; exit 1; }
[ -f "$MENU" ] || { echo "missing $MENU" >&2; exit 1; }

grep -qx 'dnsmasq' "$REQ"
grep -qx 'nginx' "$REQ"
grep -qx 'nfs-utils' "$REQ"

grep -q 'port=0' "$CONF"
grep -q 'dhcp-range=.*proxy' "$CONF"
grep -q 'enable-tftp' "$CONF"
grep -q 'tftp-root=' "$CONF"

# Safety gate: the shipped configuration must not define an authoritative
# address pool. PXE-SE starts as ProxyDHCP only.
! grep -Eq '^dhcp-range=[^,]+,[^,]+,[0-9]+h' "$CONF"
! grep -q '^dhcp-authoritative' "$CONF"

grep -q '#!ipxe' "$MENU"
grep -q 'menu ' "$MENU"

echo "PXE-SE safety contract: ok"

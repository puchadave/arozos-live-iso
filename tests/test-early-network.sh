#!/bin/sh
set -eu
fail() { echo "FAIL: $*" >&2; exit 1; }

# GRUB must request DHCP for both normal and debug live boots.
COUNT=$(grep -c 'linux /boot/vmlinuz-lts .*ip=dhcp' scripts/build-live-iso.sh || true)
[ "$COUNT" -ge 2 ] || fail "GRUB live entries must pass ip=dhcp"

# The custom initramfs must actually implement the parameter instead of
# leaving it as decorative kernel command-line text.
grep -q '/proc/cmdline' initramfs/arozos-live-init || fail "initramfs must inspect kernel cmdline"
grep -q 'ip=dhcp' initramfs/arozos-live-init || fail "initramfs must recognize ip=dhcp"
grep -q 'virtio_net' initramfs/arozos-live-init || fail "initramfs must preload VirtIO network support"
grep -q 'e1000e' initramfs/arozos-live-init || fail "initramfs must preload common physical/virtual NIC drivers"
grep -q 'udhcpc' initramfs/arozos-live-init || fail "initramfs must run DHCP before switch_root"

# Network setup has to happen before handing control to OpenRC.
DHCP_LINE=$(grep -n 'udhcpc' initramfs/arozos-live-init | head -n1 | cut -d: -f1)
SWITCH_LINE=$(grep -n 'switch_root' initramfs/arozos-live-init | tail -n1 | cut -d: -f1)
[ "$DHCP_LINE" -lt "$SWITCH_LINE" ] || fail "DHCP must run before switch_root"

echo "PASS: early live networking policy"

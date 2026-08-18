#!/bin/sh
set -eu

fail() { echo "FAIL: $*" >&2; exit 1; }

[ "$(cat VERSION)" = "0.3.2" ] || fail "VERSION must be 0.3.2"

for f in \
  requirements/core.txt \
  requirements/build.txt \
  requirements/installer.txt \
  requirements/rescue.txt \
  scripts/build-live-iso.sh \
  initramfs/arozos-live-init \
  rootfs/etc/init.d/arozos \
  rootfs/etc/init.d/arozos-net
 do
  [ -f "$f" ] || fail "missing $f"
 done

for forbidden in go git make gcc build-base gparted testdisk ddrescue mdadm lvm2 cryptsetup grub; do
  ! grep -Eq "^${forbidden}([<>=~].*)?$" requirements/core.txt || fail "$forbidden must not be in core"
done

for required in alpine-base bash ca-certificates ffmpeg iproute2 procps util-linux coreutils findutils tzdata shadow linux-lts; do
  grep -Eq "^${required}([<>=~].*)?$" requirements/core.txt || fail "missing core package $required"
done

grep -q 'make web' scripts/build-live-iso.sh || fail "ArozOS web build missing"
grep -q 'dist/web.tar.gz' scripts/build-live-iso.sh || fail "web.tar.gz extraction source missing"
grep -q 'mksquashfs' scripts/build-live-iso.sh || fail "SquashFS build missing"
! grep -Eq 'cp .*web\.tar\.gz.*ROOTFS|install .*web\.tar\.gz.*ROOTFS' scripts/build-live-iso.sh || fail "web.tar.gz must not be copied into runtime rootfs"

grep -q 'mount -t squashfs' initramfs/arozos-live-init || fail "initramfs must mount SquashFS"
grep -q 'mount -t overlay' initramfs/arozos-live-init || fail "initramfs must mount writable overlay"
grep -q 'udhcpc' rootfs/etc/init.d/arozos-net || fail "live DHCP service missing"

echo "PASS: live ISO layout policy"

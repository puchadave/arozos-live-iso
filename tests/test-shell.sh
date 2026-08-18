#!/bin/sh
set -eu
for f in scripts/*.sh apk-repo/*.sh initramfs/* rootfs/etc/init.d/*; do
  [ -f "$f" ] || continue
  case "$f" in
    *.sh) bash -n "$f" ;;
    *) sh -n "$f" ;;
  esac
done
echo "PASS: shell syntax"

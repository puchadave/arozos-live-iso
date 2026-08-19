#!/bin/sh
set -eu

BUILD=scripts/build-ipxe-client-iso.sh
[ -f "$BUILD" ] || { echo "missing $BUILD" >&2; exit 1; }

grep -q 'build-ipxe-assets.sh' "$BUILD"
grep -q 'ipxe.lkrn' "$BUILD"
grep -q 'ipxe-x86_64.efi' "$BUILD"
grep -q 'grub-mkrescue' "$BUILD"
grep -q 'report_el_torito' "$BUILD"
grep -q 'AROPXEBOOT' "$BUILD"

echo "PXE client ISO builder contract: ok"

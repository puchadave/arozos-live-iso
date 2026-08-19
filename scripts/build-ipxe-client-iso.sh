#!/usr/bin/env bash
set -euo pipefail

BASE=$(cd "$(dirname "$0")/.." && pwd)
cd "$BASE"
. ./upstream.env

VERSION=$(cat VERSION)
ARCH=${1:-x86_64}
OUT=$BASE/output
WORK=$BASE/.build/pxe-boot-$ARCH
ASSETS=$BASE/.build/ipxe-assets

if [ "$ARCH" != "x86_64" ]; then
    echo "ERROR: hybrid Legacy BIOS + UEFI PXE client ISO is currently x86_64 only" >&2
    echo "ARM64 uses a UEFI-only image path and is built separately." >&2
    exit 1
fi

mapfile -t BUILD_PKGS < <(grep -Ev '^($|#)' requirements/build.txt)
apk update
apk add --no-cache "${BUILD_PKGS[@]}"
update-ca-certificates

[ -d /usr/lib/grub/i386-pc ] || { echo "ERROR: GRUB BIOS modules missing" >&2; exit 1; }
[ -d /usr/lib/grub/x86_64-efi ] || { echo "ERROR: GRUB x86_64 UEFI modules missing" >&2; exit 1; }

"$BASE/scripts/build-ipxe-assets.sh" "$ASSETS"

rm -rf "$WORK"
mkdir -p "$WORK/iso/boot/grub" "$WORK/iso/ipxe" "$OUT"
cp "$ASSETS/ipxe.lkrn" "$WORK/iso/ipxe/ipxe.lkrn"
cp "$ASSETS/ipxe-x86_64.efi" "$WORK/iso/ipxe/ipxe-x86_64.efi"
cp "$ASSETS/SOURCE" "$WORK/iso/ipxe/SOURCE"
cp "$ASSETS/SHA256SUMS" "$WORK/iso/ipxe/SHA256SUMS"

cat > "$WORK/iso/boot/grub/grub.cfg" <<'GRUB'
set default=0
set timeout=3

menuentry "ArozOS Network Boot (iPXE)" {
    if [ "${grub_platform}" = "efi" ]; then
        chainloader /ipxe/ipxe-x86_64.efi
    else
        linux16 /ipxe/ipxe.lkrn
    fi
}

menuentry "Return to firmware / next boot device" {
    exit
}
GRUB

ISO="$OUT/arozos-pxe-boot-v${VERSION}-${ARCH}.iso"
rm -f "$ISO" "$ISO.sha256"

grub-mkrescue -o "$ISO" "$WORK/iso" -- -volid AROPXEBOOT

BOOT_REPORT=$(xorriso -indev "$ISO" -report_el_torito plain 2>&1)
printf '%s\n' "$BOOT_REPORT"
printf '%s\n' "$BOOT_REPORT" | grep -Eq 'El Torito boot img :.*BIOS' || {
    echo "ERROR: Legacy BIOS El Torito image missing" >&2
    exit 1
}
printf '%s\n' "$BOOT_REPORT" | grep -Eq 'El Torito boot img :.*UEFI' || {
    echo "ERROR: UEFI El Torito image missing" >&2
    exit 1
}

sha256sum "$ISO" > "$ISO.sha256"
echo "Built: $ISO"

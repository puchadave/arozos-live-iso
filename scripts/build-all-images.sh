#!/usr/bin/env bash
set -euo pipefail

BASE=$(cd "$(dirname "$0")/.." && pwd)
cd "$BASE"
. ./upstream.env

TARGET_ARCH=${1:-${ARCH:-x86_64}}
ARCH=$TARGET_ARCH
BUNDLE=$BASE/.build/pxe-bundle-$ARCH
OUT=$BASE/output

if [ "$ARCH" != "x86_64" ]; then
    echo "ERROR: build-all-images currently assembles the x86_64 BIOS+UEFI family." >&2
    echo "ARM64 is UEFI-only and has a separate release gate." >&2
    exit 1
fi

rm -rf "$OUT" "$BUNDLE"
mkdir -p "$OUT" "$BUNDLE/menus"

# Build independent diagnostic images first. Their immutable roots become the
# PXE test payloads, so PXE-SE never invents a second untested userspace.
for profile in live installer rescue; do
    "$BASE/scripts/build-profile-iso.sh" "$profile" "$ARCH"
done

mkdir -p \
    "$BUNDLE/$ARCH/live" \
    "$BUNDLE/$ARCH/installer" \
    "$BUNDLE/$ARCH/rescue"

for profile in live installer rescue; do
    work="$BASE/.build/${profile}-${ARCH}"
    cp "$work/vmlinuz-lts" "$BUNDLE/$ARCH/$profile/vmlinuz-lts"
    cp "$work/initramfs-lts" "$BUNDLE/$ARCH/$profile/initramfs-lts"
    cp "$work/rootfs.squashfs" "$BUNDLE/$ARCH/$profile/rootfs.squashfs"
done

write_menu() {
    local name=$1 profile=$2 mode=$3
    cat > "$BUNDLE/menus/${name}-${ARCH}.ipxe" <<EOF
#!ipxe
set base http://\${server}:8081
kernel \${base}/$ARCH/$profile/vmlinuz-lts aroz.mode=$mode aroz.source=http aroz.root_url=\${base}/$ARCH/$profile/rootfs.squashfs ip=dhcp
initrd \${base}/$ARCH/$profile/initramfs-lts
boot
EOF
}

write_menu live live live
write_menu debug live debug
write_menu installer installer installer
write_menu rescue rescue rescue

# PXE client ISO is deliberately independent of the Linux live root.
"$BASE/scripts/build-ipxe-client-iso.sh" "$ARCH"

# PXE-SE and Mega receive the exact already-built client payloads.
PXE_BUNDLE_DIR="$BUNDLE" "$BASE/scripts/build-profile-iso.sh" pxe-se "$ARCH"
PXE_BUNDLE_DIR="$BUNDLE" "$BASE/scripts/build-profile-iso.sh" mega "$ARCH"

(
    cd "$OUT"
    sha256sum ./*.iso > SHA256SUMS
)

cat > "$OUT/IMAGE-SET.txt" <<EOF
ArozOS bare-metal image set
architecture=$ARCH
version=$(cat VERSION)
images=live installer rescue pxe-boot pxe-se mega
pxe_root_mode=http-ram
EOF

printf 'Built complete image set:\n'
find "$OUT" -maxdepth 1 -type f -name '*.iso' -printf '  %f\n' | sort

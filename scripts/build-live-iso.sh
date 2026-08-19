#!/usr/bin/env bash
set -euo pipefail
BASE=$(cd "$(dirname "$0")/.." && pwd)
cd "$BASE"
. ./upstream.env
VERSION=$(cat VERSION)
OUT="$BASE/output"
WORK="$BASE/.build"
ROOTFS="$WORK/rootfs"
SRC="$WORK/arozos-upstream"
ISOROOT="$WORK/iso"
REPOFILE="$WORK/repositories"

rm -rf "$WORK" "$OUT"
mkdir -p "$WORK" "$OUT" "$ROOTFS" "$ISOROOT/boot/grub" "$ISOROOT/images"

cat > "$REPOFILE" <<REPOS
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_RELEASE}/main
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_RELEASE}/community
REPOS

mapfile -t BUILD_PKGS < <(grep -Ev '^($|#)' requirements/build.txt)
apk update
apk add --no-cache "${BUILD_PKGS[@]}"
update-ca-certificates

[ -d /usr/lib/grub/i386-pc ] || { echo "ERROR: GRUB BIOS platform modules missing" >&2; exit 1; }
[ -d /usr/lib/grub/x86_64-efi ] || { echo "ERROR: GRUB UEFI platform modules missing" >&2; exit 1; }

echo "==> Fetching ArozOS upstream: $AROZOS_REF"
git clone --depth=1 "$AROZOS_REPO" "$SRC"
if [ "$AROZOS_REF" != "master" ]; then
    git -C "$SRC" fetch --depth=1 origin "$AROZOS_REF"
    git -C "$SRC" checkout --detach FETCH_HEAD
fi

pushd "$SRC/src" >/dev/null
go mod download
CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o "$WORK/arozos" .
make web
popd >/dev/null

echo "==> Creating minimal Alpine root filesystem"
mapfile -t CORE_PKGS < <(grep -Ev '^($|#)' requirements/core.txt)
mkdir -p "$ROOTFS/etc/apk/keys"
cp /etc/apk/keys/* "$ROOTFS/etc/apk/keys/"
apk --root "$ROOTFS" --arch "$ARCH" --initdb --keys-dir /etc/apk/keys --repositories-file "$REPOFILE" add "${CORE_PKGS[@]}"
cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
printf 'arozos-live\n' > "$ROOTFS/etc/hostname"
mkdir -p "$ROOTFS/opt/arozos" "$ROOTFS/opt/arozos/files" "$ROOTFS/opt/arozos/tmp"
install -m 0755 "$WORK/arozos" "$ROOTFS/opt/arozos/arozos"

# Critical live-image rule: unpack the ArozOS web payload NOW, into the rootfs.
# The runtime image never carries or re-extracts web.tar.gz.
tar -xzf "$SRC/src/dist/web.tar.gz" -C "$ROOTFS/opt/arozos"

cp -a rootfs/. "$ROOTFS/"
chmod 0755 "$ROOTFS/etc/init.d/arozos" "$ROOTFS/etc/init.d/arozos-net"
chroot "$ROOTFS" addgroup -S arozos 2>/dev/null || true
chroot "$ROOTFS" adduser -S -D -H -h /opt/arozos -s /sbin/nologin -G arozos arozos 2>/dev/null || true
chroot "$ROOTFS" chown -R arozos:arozos /opt/arozos
mkdir -p "$ROOTFS/etc/runlevels/default"
ln -sf /etc/init.d/arozos-net "$ROOTFS/etc/runlevels/default/arozos-net"
ln -sf /etc/init.d/arozos "$ROOTFS/etc/runlevels/default/arozos"

echo "==> Building SquashFS root (not a RAM disk)"
mksquashfs "$ROOTFS" "$ISOROOT/images/rootfs.squashfs" -comp xz -b 1M -noappend

KVER=""
for moddir in "$ROOTFS"/lib/modules/*; do
    [ -d "$moddir" ] || continue
    KVER=${moddir##*/}
    break
done
[ -n "$KVER" ]
cp -L "$ROOTFS/boot/vmlinuz-lts" "$ISOROOT/boot/vmlinuz-lts"

echo "==> Building custom initramfs for ISO SquashFS + overlay"
mkinitfs -b "$ROOTFS" \
    -P "$BASE/initramfs/features.d" \
    -F "base arozlive" \
    -i "$BASE/initramfs/arozos-live-init" \
    -o "$ISOROOT/boot/initramfs-lts" \
    "$KVER"

cat > "$ISOROOT/boot/grub/grub.cfg" <<'GRUB'
set default=0
set timeout=5

menuentry "ArozOS Alpine Live" {
    linux /boot/vmlinuz-lts aroz.mode=live quiet
    initrd /boot/initramfs-lts
}

menuentry "ArozOS Alpine Live (debug)" {
    linux /boot/vmlinuz-lts aroz.mode=live
    initrd /boot/initramfs-lts
}
GRUB

echo "==> Creating hybrid GRUB ISO (Legacy BIOS + UEFI)"
ISO="$OUT/arozos-alpine-live-v${VERSION}-${ARCH}.iso"
grub-mkrescue -o "$ISO" "$ISOROOT" -- -volid AROZOSLIVE

echo "==> Verifying El Torito BIOS and UEFI boot entries"
BOOT_REPORT=$(xorriso -indev "$ISO" -report_el_torito plain 2>&1)
printf '%s\n' "$BOOT_REPORT"
printf '%s\n' "$BOOT_REPORT" | grep -Eq 'El Torito boot img :.*BIOS' || { echo "ERROR: Legacy BIOS El Torito boot image missing" >&2; exit 1; }
printf '%s\n' "$BOOT_REPORT" | grep -Eq 'El Torito boot img :.*UEFI' || { echo "ERROR: UEFI El Torito boot image missing" >&2; exit 1; }

sha256sum "$ISO" > "$OUT/SHA256SUMS"
printf 'Built: %s\n' "$ISO"

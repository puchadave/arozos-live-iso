#!/usr/bin/env bash
set -euo pipefail

BASE=$(cd "$(dirname "$0")/.." && pwd)
cd "$BASE"
. ./upstream.env
# shellcheck source=scripts/lib/profile.sh
. "$BASE/scripts/lib/profile.sh"

PROFILE=${1:-live}
TARGET_ARCH=${2:-${ARCH:-x86_64}}
ARCH=$TARGET_ARCH
load_image_profile "$PROFILE" "$ARCH"

if [ "$IMAGE_ID" = "pxe-boot" ]; then
    exec "$BASE/scripts/build-ipxe-client-iso.sh" "$ARCH"
fi

if [ "$ARCH" != "x86_64" ]; then
    echo "ERROR: $IMAGE_ID/$ARCH needs the UEFI-only ARM64 builder." >&2
    echo "This x86_64 builder intentionally does not pretend to provide Legacy BIOS on ARM." >&2
    exit 1
fi

VERSION=$(cat VERSION)
OUT=$BASE/output
WORK=$BASE/.build/${IMAGE_ID}-${ARCH}
ROOTFS=$WORK/rootfs
ISOROOT=$WORK/iso
REPOFILE=$WORK/repositories
CACHE=$BASE/.build/cache
AROZ_SRC=$CACHE/arozos-src
AROZ_BIN=$CACHE/arozos-${AROZOS_REF}-${ARCH}
AROZ_WEB=$CACHE/arozos-web-${AROZOS_REF}.tar.gz
IPXE_ASSETS=$BASE/.build/ipxe-assets

rm -rf "$WORK"
mkdir -p "$WORK" "$OUT" "$ROOTFS" "$ISOROOT/boot/grub" "$ISOROOT/images" "$CACHE"

mapfile -t BUILD_PKGS < <(grep -Ev '^($|#)' requirements/build.txt)
apk update
apk add --no-cache "${BUILD_PKGS[@]}"
update-ca-certificates

[ -d /usr/lib/grub/i386-pc ] || { echo "ERROR: GRUB BIOS platform modules missing" >&2; exit 1; }
[ -d /usr/lib/grub/x86_64-efi ] || { echo "ERROR: GRUB UEFI platform modules missing" >&2; exit 1; }

cat > "$REPOFILE" <<REPOS
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_RELEASE}/main
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_RELEASE}/community
REPOS

if [ "$ENABLE_AROZOS" = "1" ]; then
    if [ ! -d "$AROZ_SRC/.git" ] || [ "$(git -C "$AROZ_SRC" rev-parse HEAD 2>/dev/null || true)" != "$AROZOS_REF" ]; then
        rm -rf "$AROZ_SRC"
        git init -q "$AROZ_SRC"
        git -C "$AROZ_SRC" remote add origin "$AROZOS_REPO"
        git -C "$AROZ_SRC" fetch -q --depth=1 origin "$AROZOS_REF"
        git -C "$AROZ_SRC" checkout -q --detach FETCH_HEAD
    fi

    if [ ! -s "$AROZ_BIN" ]; then
        echo "==> Building ArozOS $AROZOS_REF for $ARCH"
        pushd "$AROZ_SRC/src" >/dev/null
        go mod download
        CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
            go build -trimpath -ldflags='-s -w' -o "$AROZ_BIN" .
        popd >/dev/null
    fi

    if [ ! -s "$AROZ_WEB" ]; then
        echo "==> Building ArozOS web payload"
        pushd "$AROZ_SRC/src" >/dev/null
        make web
        cp dist/web.tar.gz "$AROZ_WEB"
        popd >/dev/null
    fi
fi

echo "==> Resolving rootfs packages for $IMAGE_ID/$ARCH"
PKGS=()
for manifest in $PACKAGE_MANIFESTS; do
    [ -f "$BASE/requirements/$manifest" ] || {
        echo "ERROR: missing package manifest requirements/$manifest" >&2
        exit 1
    }
    while IFS= read -r pkg; do
        case "$pkg" in ''|'#'*) continue ;; esac
        PKGS+=("$pkg")
    done < "$BASE/requirements/$manifest"
done

mkdir -p "$ROOTFS/etc/apk/keys"
cp /etc/apk/keys/* "$ROOTFS/etc/apk/keys/"
apk --root "$ROOTFS" --arch "$ARCH" --initdb \
    --keys-dir /etc/apk/keys \
    --repositories-file "$REPOFILE" \
    add "${PKGS[@]}"

cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
printf 'arozos-%s\n' "$IMAGE_ID" > "$ROOTFS/etc/hostname"
cp -a rootfs/. "$ROOTFS/"

# Make repository-provided scripts executable after copying the overlay.
for executable in \
    "$ROOTFS/etc/init.d/arozos" \
    "$ROOTFS/etc/init.d/arozos-net" \
    "$ROOTFS/etc/init.d/arozos-mode" \
    "$ROOTFS/etc/init.d/arozos-pxe-se" \
    "$ROOTFS/usr/local/sbin/arozos-mode-init" \
    "$ROOTFS/usr/local/sbin/arozos-console"; do
    [ -f "$executable" ] && chmod 0755 "$executable"
done

if [ "$ENABLE_AROZOS" = "1" ]; then
    mkdir -p "$ROOTFS/opt/arozos" "$ROOTFS/opt/arozos/files" "$ROOTFS/opt/arozos/tmp"
    install -m 0755 "$AROZ_BIN" "$ROOTFS/opt/arozos/arozos"
    tar -xzf "$AROZ_WEB" -C "$ROOTFS/opt/arozos"

    # Fixed numeric service identity keeps the rootfs build cross-architecture
    # friendly and avoids executing target-architecture binaries in chroot.
    grep -q '^arozos:' "$ROOTFS/etc/group" || echo 'arozos:x:910:' >> "$ROOTFS/etc/group"
    grep -q '^arozos:' "$ROOTFS/etc/passwd" || \
        echo 'arozos:x:910:910:ArozOS service:/opt/arozos:/sbin/nologin' >> "$ROOTFS/etc/passwd"
    if [ -f "$ROOTFS/etc/shadow" ]; then
        grep -q '^arozos:' "$ROOTFS/etc/shadow" || \
            echo 'arozos:!:1:0:99999:7:::' >> "$ROOTFS/etc/shadow"
    fi
    chown -R 910:910 "$ROOTFS/opt/arozos"
fi

mkdir -p "$ROOTFS/etc/runlevels/default"
ln -sf /etc/init.d/arozos-mode "$ROOTFS/etc/runlevels/default/arozos-mode"
ln -sf /etc/init.d/arozos-net "$ROOTFS/etc/runlevels/default/arozos-net"
if [ "$ENABLE_AROZOS" = "1" ]; then
    ln -sf /etc/init.d/arozos "$ROOTFS/etc/runlevels/default/arozos"
fi

if [ "$MODE" = "pxe-se" ] || [ "$MODE" = "mega" ]; then
    "$BASE/scripts/build-ipxe-assets.sh" "$IPXE_ASSETS"
    mkdir -p "$ROOTFS/var/lib/arozos-pxe-se/tftp" "$ROOTFS/var/lib/arozos-pxe-se/http/menus"
    cp "$IPXE_ASSETS/undionly.kpxe" "$ROOTFS/var/lib/arozos-pxe-se/tftp/undionly.kpxe"
    cp "$IPXE_ASSETS/ipxe-x86_64.efi" "$ROOTFS/var/lib/arozos-pxe-se/tftp/ipxe-x86_64.efi"
    if [ -f "$IPXE_ASSETS/ipxe-arm64.efi" ]; then
        cp "$IPXE_ASSETS/ipxe-arm64.efi" "$ROOTFS/var/lib/arozos-pxe-se/tftp/ipxe-arm64.efi"
    fi

    if [ -n "${PXE_BUNDLE_DIR:-}" ] && [ -d "$PXE_BUNDLE_DIR" ]; then
        cp -a "$PXE_BUNDLE_DIR/." "$ROOTFS/var/lib/arozos-pxe-se/http/"
    fi
    ln -sf /etc/init.d/arozos-pxe-se "$ROOTFS/etc/runlevels/default/arozos-pxe-se"
fi

cat > "$ROOTFS/etc/arozos-image" <<EOF
image_id=$IMAGE_ID
mode=$MODE
version=$VERSION
architecture=$ARCH
alpine=$ALPINE_RELEASE
arozos_commit=$AROZOS_REF
ipxe_commit=$IPXE_REF
EOF

echo "==> Building immutable SquashFS root"
mksquashfs "$ROOTFS" "$ISOROOT/images/rootfs.squashfs" -comp xz -b 1M -noappend
cp "$ISOROOT/images/rootfs.squashfs" "$WORK/rootfs.squashfs"

KVER=""
for moddir in "$ROOTFS"/lib/modules/*; do
    [ -d "$moddir" ] || continue
    KVER=${moddir##*/}
    break
done
[ -n "$KVER" ] || { echo "ERROR: Linux module tree missing" >&2; exit 1; }

cp -L "$ROOTFS/boot/vmlinuz-lts" "$ISOROOT/boot/vmlinuz-lts"
cp -L "$ROOTFS/boot/vmlinuz-lts" "$WORK/vmlinuz-lts"

mkinitfs -b "$ROOTFS" \
    -P "$BASE/initramfs/features.d" \
    -F "base network dhcp arozlive" \
    -i "$BASE/initramfs/arozos-live-init" \
    -o "$ISOROOT/boot/initramfs-lts" \
    "$KVER"
cp "$ISOROOT/boot/initramfs-lts" "$WORK/initramfs-lts"

if [ "$IMAGE_ID" = "mega" ]; then
    cp "$BASE/boot/grub/mega.cfg" "$ISOROOT/boot/grub/grub.cfg"
    mkdir -p "$ISOROOT/ipxe"
    cp "$IPXE_ASSETS/ipxe.lkrn" "$ISOROOT/ipxe/ipxe.lkrn"
    cp "$IPXE_ASSETS/ipxe-x86_64.efi" "$ISOROOT/ipxe/ipxe-x86_64.efi"
else
    DHCP_ARG=""
    [ "$EARLY_DHCP" = "1" ] && DHCP_ARG="ip=dhcp"
    cat > "$ISOROOT/boot/grub/grub.cfg" <<EOF
set default=0
set timeout=5

menuentry "$BOOT_TITLE" {
    linux /boot/vmlinuz-lts aroz.mode=$MODE aroz.source=iso aroz.volume=$VOLUME_ID $DHCP_ARG quiet
    initrd /boot/initramfs-lts
}

menuentry "$BOOT_TITLE (debug)" {
    linux /boot/vmlinuz-lts aroz.mode=$MODE aroz.source=iso aroz.volume=$VOLUME_ID $DHCP_ARG
    initrd /boot/initramfs-lts
}

menuentry "Return to firmware / next boot device" {
    exit
}
EOF
fi

ISO="$OUT/arozos-${IMAGE_ID}-v${VERSION}-${ARCH}.iso"
rm -f "$ISO" "$ISO.sha256"

echo "==> Creating $IMAGE_ID hybrid GRUB ISO"
grub-mkrescue -o "$ISO" "$ISOROOT" -- -volid "$VOLUME_ID"

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
cat > "$ISO.manifest" <<EOF
image=$IMAGE_ID
mode=$MODE
version=$VERSION
architecture=$ARCH
volume_id=$VOLUME_ID
alpine=$ALPINE_RELEASE
arozos_commit=$AROZOS_REF
ipxe_commit=$IPXE_REF
sha256=$(awk '{print $1}' "$ISO.sha256")
EOF

echo "Built: $ISO"

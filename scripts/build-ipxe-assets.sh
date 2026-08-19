#!/usr/bin/env bash
set -euo pipefail

BASE=$(cd "$(dirname "$0")/.." && pwd)
cd "$BASE"
. ./upstream.env

OUT=${1:-$BASE/.build/ipxe-assets}
SRC=$BASE/.build/ipxe-src
JOBS=${JOBS:-2}

mkdir -p "$BASE/.build" "$OUT"

if [ ! -d "$SRC/.git" ] || [ "$(git -C "$SRC" rev-parse HEAD 2>/dev/null || true)" != "$IPXE_REF" ]; then
    rm -rf "$SRC"
    git init -q "$SRC"
    git -C "$SRC" remote add origin "$IPXE_REPO"
    git -C "$SRC" fetch -q --depth=1 origin "$IPXE_REF"
    git -C "$SRC" checkout -q --detach FETCH_HEAD
fi

rm -rf "$OUT"
mkdir -p "$OUT"

echo "==> Building pinned iPXE $IPXE_REF"
make -C "$SRC/src" -j"$JOBS" \
    bin/ipxe.lkrn \
    bin/undionly.kpxe \
    EMBED="$BASE/ipxe/bootstrap.ipxe"

make -C "$SRC/src" -j"$JOBS" \
    bin-x86_64-efi/ipxe.efi \
    EMBED="$BASE/ipxe/bootstrap.ipxe"

cp "$SRC/src/bin/ipxe.lkrn" "$OUT/ipxe.lkrn"
cp "$SRC/src/bin/undionly.kpxe" "$OUT/undionly.kpxe"
cp "$SRC/src/bin-x86_64-efi/ipxe.efi" "$OUT/ipxe-x86_64.efi"

# ARM64 UEFI is built natively on ARM64 or with an explicitly available GNU
# cross toolchain. Absence of the cross compiler never produces a fake ARM64
# artifact; the architecture-specific release gate handles that separately.
if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
    make -C "$SRC/src" -j"$JOBS" \
        bin-arm64-efi/ipxe.efi \
        EMBED="$BASE/ipxe/bootstrap.ipxe"
    cp "$SRC/src/bin-arm64-efi/ipxe.efi" "$OUT/ipxe-arm64.efi"
elif command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
    make -C "$SRC/src" -j"$JOBS" \
        CROSS_COMPILE=aarch64-linux-gnu- \
        bin-arm64-efi/ipxe.efi \
        EMBED="$BASE/ipxe/bootstrap.ipxe"
    cp "$SRC/src/bin-arm64-efi/ipxe.efi" "$OUT/ipxe-arm64.efi"
else
    echo "NOTE: ARM64 iPXE asset not built on this host (no ARM64 compiler)" >&2
fi

(
    cd "$OUT"
    sha256sum ipxe.lkrn undionly.kpxe ipxe-x86_64.efi > SHA256SUMS
    if [ -f ipxe-arm64.efi ]; then
        sha256sum ipxe-arm64.efi >> SHA256SUMS
    fi
)

cat > "$OUT/SOURCE" <<EOF
repository=$IPXE_REPO
commit=$IPXE_REF
embed=ipxe/bootstrap.ipxe
EOF

echo "Built iPXE assets in $OUT"

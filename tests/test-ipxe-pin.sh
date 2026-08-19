#!/bin/sh
set -eu

[ -f upstream.env ]
[ -f scripts/build-ipxe-assets.sh ]
[ -f ipxe/bootstrap.ipxe ]

grep -q '^IPXE_REPO=' upstream.env
grep -Eq '^IPXE_REF=.*[0-9a-f]{40}' upstream.env
grep -q 'ipxe.lkrn' scripts/build-ipxe-assets.sh
grep -q 'undionly.kpxe' scripts/build-ipxe-assets.sh
grep -q 'bin-x86_64-efi/ipxe.efi' scripts/build-ipxe-assets.sh
grep -q 'bin-arm64-efi/ipxe.efi' scripts/build-ipxe-assets.sh
grep -q 'EMBED=' scripts/build-ipxe-assets.sh
grep -q '#!ipxe' ipxe/bootstrap.ipxe

echo "pinned iPXE contract: ok"

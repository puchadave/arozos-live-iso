#!/bin/sh
set -eu

[ -f scripts/lib/profile.sh ]
[ -f scripts/build-profile-iso.sh ]
[ -f scripts/build-all-images.sh ]

grep -q 'profiles/.*\.conf' scripts/lib/profile.sh
grep -q 'IMAGE_ID' scripts/build-profile-iso.sh
grep -q 'PACKAGE_MANIFESTS' scripts/build-profile-iso.sh
grep -q 'arozos-.*${ARCH}.*\.iso\|arozos-${IMAGE_ID}.*${ARCH}.*\.iso' scripts/build-profile-iso.sh

grep -q 'live' scripts/build-all-images.sh
grep -q 'installer' scripts/build-all-images.sh
grep -q 'rescue' scripts/build-all-images.sh
grep -q 'pxe-boot' scripts/build-all-images.sh
grep -q 'pxe-se' scripts/build-all-images.sh
grep -q 'mega' scripts/build-all-images.sh

echo "build dispatcher contract: ok"

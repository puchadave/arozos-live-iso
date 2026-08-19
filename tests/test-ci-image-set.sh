#!/bin/sh
set -eu

WF=.github/workflows/ci.yml
[ -f "$WF" ] || { echo "missing $WF" >&2; exit 1; }

grep -q 'scripts/build-all-images.sh' "$WF" || {
    echo "CI must build the complete image set" >&2
    exit 1
}

for token in \
    'arozos-live-' \
    'arozos-installer-' \
    'arozos-rescue-' \
    'arozos-pxe-boot-' \
    'arozos-pxe-se-' \
    'arozos-mega-'; do
    grep -q "$token" "$WF" || {
        echo "CI artifact contract missing $token" >&2
        exit 1
    }
done

grep -q 'output/SHA256SUMS' "$WF" || {
    echo "CI must publish the image-set checksums" >&2
    exit 1
}

grep -q 'output/IMAGE-SET.txt' "$WF" || {
    echo "CI must publish image-set metadata" >&2
    exit 1
}

echo "complete CI image-set contract: ok"

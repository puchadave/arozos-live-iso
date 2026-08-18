#!/bin/sh
set -eu
for t in tests/test-*.sh; do echo "==> $t"; sh "$t"; done

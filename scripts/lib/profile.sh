#!/usr/bin/env bash
set -euo pipefail

load_image_profile() {
    local profile=${1:?profile name required}
    local arch=${2:?architecture required}
    local profile_file="$BASE/profiles/${profile}.conf"

    [ -f "$profile_file" ] || {
        echo "ERROR: unknown image profile: $profile" >&2
        return 1
    }

    # shellcheck source=/dev/null
    . "$profile_file"

    : "${IMAGE_ID:?profile missing IMAGE_ID}"
    : "${MODE:?profile missing MODE}"
    : "${VOLUME_ID:?profile missing VOLUME_ID}"
    : "${ARCHES:?profile missing ARCHES}"
    : "${PACKAGE_MANIFESTS:=}"
    : "${ENABLE_AROZOS:=0}"
    : "${EARLY_DHCP:=0}"
    : "${BOOT_TITLE:=$IMAGE_ID}"

    case " $ARCHES " in
        *" $arch "*) ;;
        *)
            echo "ERROR: profile $profile does not support architecture $arch" >&2
            return 1
            ;;
    esac
}

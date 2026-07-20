#!/usr/bin/env bash

set -e

# Board setup is carried by the selected ROCK Pi S base DTB.

# Runtime firmware operations used by nerves_runtime for validation, reverts,
# status checks, and factory resets.
mkdir -p "${TARGET_DIR}/usr/share/fwup"
NERVES_SDK_IMAGES="${NERVES_DEFCONFIG_DIR}" \
    "${HOST_DIR}/usr/bin/fwup" -c -f "${NERVES_DEFCONFIG_DIR}/fwup-ops.conf" \
    -o "${TARGET_DIR}/usr/share/fwup/ops.fw"
ln -sf ops.fw "${TARGET_DIR}/usr/share/fwup/revert.fw"

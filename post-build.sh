#!/usr/bin/env bash

set -e

# Copy the kernel's compiled DT overlays into /boot, flat, matching the
# ${overlay_file}.dtbo load path in uboot/boot.env's uname_boot script.
# BR2_LINUX_KERNEL_DTB_OVERLAY_SUPPORT only enables *compiling* overlays --
# Buildroot doesn't install them anywhere on its own. Ported from
# buildroot.rockchip.ext/board/RK3308/post-image.sh, which does the
# equivalent copy for its separate FAT boot partition.
LINUX_BUILD_DIR=$(find "$BASE_DIR/build" -maxdepth 1 -name 'linux-*' -type d | head -n1)
if [ -n "$LINUX_BUILD_DIR" ] && [ -d "$LINUX_BUILD_DIR/arch/arm64/boot/dts/rockchip/overlay" ]; then
    mkdir -p "$1/boot"
    cp -a "$LINUX_BUILD_DIR"/arch/arm64/boot/dts/rockchip/overlay/*.dtbo "$1/boot/" 2>/dev/null || true
fi

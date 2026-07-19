#!/usr/bin/env bash

set -e

#
# Packs the Rockchip boot chain (idbloader/trust/u-boot) that the RK3308
# boot ROM expects, then hands off to the standard Nerves fwup.conf
# generation + post-createfs hook.
#
# This is a port of buildroot.rockchip.ext/board/RK3308/post-image.sh's
# blob-packing steps to Nerves' BR2_ROOTFS_POST_IMAGE_SCRIPT conventions.
# Unlike that plain-Buildroot script, this does NOT stage a kernel Image,
# device tree or boot.scr into $BINARIES_DIR -- those are installed
# straight into the rootfs's /boot by BR2_LINUX_KERNEL_INSTALL_TARGET and
# rootfs_overlay/boot, and loaded from there by uboot/boot.env at runtime.
#

FWUP_CONFIG=$NERVES_DEFCONFIG_DIR/fwup.conf

if ! command -v mix > /dev/null 2>&1; then
    echo "ERROR: Elixir/Mix is required to generate fwup.conf but was not found on your PATH."
    echo "Please install Elixir: https://elixir-lang.org/install.html"
    exit 1
fi

RKBIN=$BINARIES_DIR/rkbin
RKTOOLS=$RKBIN/tools
BOARD_DIR=$NERVES_DEFCONFIG_DIR/board
# NOTE: 'uboot-*' also matches host-uboot-tools's build dir
# (uboot-tools-<version>), so anchor on a hex commit hash to get the
# actual U-Boot source checkout instead.
UBOOT_BUILD_DIR=$(find "$BASE_DIR/build" -maxdepth 1 -name 'uboot-[0-9a-f]*' -type d | head -n1)

if [ -z "$UBOOT_BUILD_DIR" ]; then
    echo "ERROR: could not find the uboot-<commit> build directory under $BASE_DIR/build"
    exit 1
fi

# Do not silently package a stale/default-configured U-Boot. The Radxa fork
# needs a small Kconfig compatibility patch before these fragment settings can
# survive olddefconfig.
for expected in \
    'CONFIG_ENV_IS_NOWHERE=y' \
    'CONFIG_DOS_PARTITION=y'; do
    if ! grep -qx "$expected" "$UBOOT_BUILD_DIR/.config"; then
        echo "ERROR: U-Boot .config is missing: $expected"
        echo "Run 'make uboot-dirclean uboot' in the Buildroot output directory."
        exit 1
    fi
done

# Persistent MMC environment corrupts the Linux handoff in this vendor U-Boot.
# Boot through a standard distro boot script while ENV_IS_NOWHERE is selected.
"$HOST_DIR/bin/mkimage" -A arm64 -T script -C none \
    -n "Nerves ROCK Pi S boot" \
    -d "$NERVES_DEFCONFIG_DIR/uboot/boot.cmd" \
    "$BINARIES_DIR/boot.scr"

# Pack U-Boot proper into the Rockchip loaderimage format
"$RKTOOLS/loaderimage" --pack --uboot "$UBOOT_BUILD_DIR/u-boot-dtb.bin" "$BINARIES_DIR/uboot.img" 0x600000 --size 1024 1

# Pack ATF bl31 into trust.img
cat > "$UBOOT_BUILD_DIR/trust.ini" <<EOF
[VERSION]
MAJOR=1
MINOR=0
[BL30_OPTION]
SEC=0
[BL31_OPTION]
SEC=1
PATH=$BOARD_DIR/rk3308_bl31_v2.10.elf
ADDR=0x00010000
[BL32_OPTION]
SEC=0
[BL33_OPTION]
SEC=0
[OUTPUT]
PATH=$BINARIES_DIR/trust.img
EOF
"$RKTOOLS/trust_merger" --size 1024 1 "$UBOOT_BUILD_DIR/trust.ini"

# Pack the DDR init blob + miniloader into idbloader.img
"$UBOOT_BUILD_DIR/tools/mkimage" -n rk3308 -T rksd -d "$BOARD_DIR/rk3308_ddr_589MHz_uart0_m0_v1.26.bin" "$BINARIES_DIR/idbloader.img"
cat "$BOARD_DIR/rk3308_miniloader_emmc_port_support_sd_20190717.bin" >> "$BINARIES_DIR/idbloader.img"

# Reproducible U-Boot bring-up checkpoint. Keep the bootloader override until
# the persistent U-Boot environment is fully reproduced from source. The
# kernel and DTB intentionally come from the current Buildroot build.
KNOWN_GOOD="$NERVES_DEFCONFIG_DIR/known_good"
cp "$KNOWN_GOOD/uboot.img" "$BINARIES_DIR/uboot.img"

# fwup.conf.eex includes fwup_include/fwup-common.conf at fwup-runtime
# via ${NERVES_SDK_IMAGES}, which resolves to this images dir in the
# packaged artifact -- so that directory has to actually be here too.
cp -rf "$NERVES_DEFCONFIG_DIR/fwup_include" "$BINARIES_DIR"

(cd "$NERVES_DEFCONFIG_DIR" && ELIXIR_ERL_OPTIONS="+fnu" mix generate_fwup_conf)

"$BR2_EXTERNAL_NERVES_PATH/board/nerves-common/post-createfs.sh" "$TARGET_DIR" "$FWUP_CONFIG"

# Getting U-Boot to build correctly for Rockchip boards is easy to get
# subtly wrong (e.g. a bad BL31 path) while the build still "succeeds".
# Catch that here rather than discovering it as a bricked board.
if [ -f "$NERVES_DEFCONFIG_DIR/build.log" ] && grep -iq "Some images are invalid" "$NERVES_DEFCONFIG_DIR/build.log"; then
    echo "ERROR: U-Boot reported invalid images. Check the BL31 path in this script."
    exit 1
fi

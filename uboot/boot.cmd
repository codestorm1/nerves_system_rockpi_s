# This vendor U-Boot must use ENV_IS_NOWHERE, so import the Nerves metadata
# environment explicitly from its reserved raw SD-card blocks. Select the
# rootfs that fwup marked active; fall back to A if the import is invalid.
mmc read ${ramdisk_addr_r} 0x7800 0x40
env import -c ${ramdisk_addr_r} 0x8000
if test "${nerves_fw_active}" = "b"; then
    echo "Booting Nerves rootfs B"
    setenv nerves_root /dev/mmcblk2p3
else
    echo "Booting Nerves rootfs A"
    setenv nerves_root /dev/mmcblk2p2
fi

setenv bootargs "root=${nerves_root} rootfstype=squashfs earlyprintk console=ttyS0,115200n8 rw rootwait"
fatload mmc 0:1 ${fdt_addr_r} rk3308-rock-s0.dtb
fatload mmc 0:1 ${kernel_addr_r} Image
fdt addr ${fdt_addr_r}
fdt set /chosen bootargs "${bootargs}"
booti ${kernel_addr_r} - ${fdt_addr_r}

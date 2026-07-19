setenv bootargs "root=/dev/mmcblk2p2 rootfstype=squashfs earlyprintk console=ttyS0,115200n8 rw rootwait"
fatload mmc 0:1 ${fdt_addr_r} rk3308-rock-s0.dtb
fatload mmc 0:1 ${kernel_addr_r} Image
booti ${kernel_addr_r} - ${fdt_addr_r}

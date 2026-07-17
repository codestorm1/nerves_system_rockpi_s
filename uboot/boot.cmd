setenv bootargs "root=/dev/mmcblk0p2 earlyprintk console=ttyS0,115200n8 rw rootwait"
fatload mmc 0:1 ${fdt_addr_r} rk3308-rock-pi-s.dtb
fatload mmc 0:1 ${kernel_addr_r} Image
booti ${kernel_addr_r} - ${fdt_addr_r}

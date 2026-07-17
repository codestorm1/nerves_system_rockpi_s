# Known-good ROCK Pi S bring-up binaries

These are the exact boot components that first booted the Nerves smoke-test
firmware through Linux, Erlang/OTP 27, IEx, Ethernet, and DHCP on the RK3308
ROCK Pi S on 2026-07-16.

The working combination was:

- Nerves partition layout and squashfs root filesystem from this system
- `uboot.img`: vendor U-Boot 2017.09 built with GCC 10.3, with
  `CONFIG_DOS_PARTITION=y` and `CONFIG_ENV_IS_NOWHERE=y`
- `Image` and board DTB from the local known-working
  `buildroot.rockchip.ext` output
- `boot.scr`, `vars.txt`, and the UART0 overlay from that same output

This directory is a recovery/reproduction checkpoint while the reference
kernel patch stack is made reproducible from source. It is not the intended
long-term packaging mechanism.

## Checksums

```text
6df2fb78aaca1273590a53eaccde0a4884fede0fc23c49272b596d3d9c7984d9  uboot.img
19451aee13adf95242cd73b534e9394af39fa597cbf55fc64b613b1fbdf87f04  Image
a1cd01ee18d44936375e4d452352676c44c3c4087e6e012921e20766e659a089  rockchip/rk3308-rock-pi-s.dtb
948cd21831bfb6d1beea06ed784eee45ef4f4271704c387bb3a062fd4c97e792  boot.scr
fd719d558e1e274154819567d63b2501c5587925eeec78dab20038ba4f8ff2ba  vars.txt
6167fe3a401f3e274697582017b63bbc38fbfecfc5152f73f7e9a302a4e55a07  rockchip/overlays/rk3308-uart0.dtbo
```

## Card layout used during the successful test

The Nerves card's FAT BOOT partition contained `Image`, `boot.scr`,
`vars.txt`, and the `rockchip/` tree from this directory. `uboot.img` was
written at sector 16384 (8 MiB):

```sh
sudo dd if=known_good/uboot.img of=/dev/SDCARD \
  bs=512 seek=16384 conv=notrunc,fsync status=progress
```

Always replace `/dev/SDCARD` with a separately verified removable device.

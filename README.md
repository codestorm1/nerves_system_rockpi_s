# nerves_system_rockpi_s

Nerves system for the Radxa ROCK Pi S (RK3308, aarch64 cortex-a35), and
eventually the ROCK S Core (rCore) SoM.

There is no official Nerves system for the RK3308 (or any Rockchip SoC) yet.
This is a from-scratch port, combining pieces of two working references:

- [`buildroot.rockchip.ext`](../buildroot.rockchip.ext) -- a plain Buildroot
  external tree that Radxa has confirmed boots on this exact hardware. It's
  the source for the RK3308-specific boot chain (U-Boot/kernel pins,
  Rockchip blobs, boot-ROM-mandated flash offsets).
- [`nerves_system_radxa_cm3`](https://github.com/sportalliance/nerves_system_radxa_cm3) --
  a working Nerves system for a *different* Rockchip SoC (RK3566). It's the
  source for the Nerves-specific A/B switching logic and fwup partition layout
  pattern.

## Status: Linux 5.10 boots Nerves on ROCK Pi S hardware

`mix firmware` succeeds end-to-end for the companion app
(`../rockpi_s_smoke_test`), and the resulting firmware boots Linux 5.10.209,
mounts the squashfs root, starts Erlang/OTP 27 and reaches IEx on real ROCK Pi
S hardware. UART0 remains usable at 115200 throughout boot, Ethernet links at
100 Mbps, userspace GPIO was verified with `Circuits.GPIO` on GPIO 15, and
full A/B updates have been verified over Ethernet in both directions.

What's retained from the known-working plain-Buildroot config (high
confidence):

- U-Boot source/pin: `radxa/u-boot.git` @ `233a23e3ed0b3e5250253ee455c3c5df2080f99c`, `rock-pi-s-rk3308` defconfig
- Kernel source/version: `radxa/kernel.git` branch `linux-5.10-gen-rkr8-buildroot`, `rk3308_linux` defconfig, with shared ROCK Pi S hardware plus explicit wireless and no-wireless DTS variants; this target selects `rockchip/rk3308-rock-pi-s-no-wireless`
- Rockchip blobs: DDR init, ATF bl31, miniloader (`board/`), and the `rkbin` package providing `loaderimage`/`trust_merger` (`package/rkbin/`)
- Boot-ROM-mandated flash offsets: idbloader@32K, uboot.img@8M, trust.img@12M (from `buildroot.rockchip.ext/board/RK3308/genimage.cfg`)

What's **adapted from a working Nerves system for a different chip**
(medium confidence -- the pattern is proven, the RK3308-specific values
aren't):

- FAT boot partition containing per-slot kernel Images and device trees plus `boot.scr`,
  followed by Nerves A/B squashfs root partitions and an application-data
  partition.
- `uboot/boot.env` -- the baked-in U-Boot environment with Nerves A/B slot
  logic (`nerves_fw_active`, `nerves_init`, `uname_boot`), built via
  `BR2_PACKAGE_HOST_UBOOT_TOOLS_ENVIMAGE`.
- `fwup.conf.eex` / `fwup_include/fwup-common.conf` -- partition layout and
  firmware update tasks.

Resolved by inspecting the Phase 0 build's actual U-Boot output
(`buildroot/output/build/uboot-233a23e3.../`):

- `radxa/u-boot.git` @ `233a23e3e` does **not** produce a merged
  `u-boot-rockchip.bin` -- confirms the three separately-packed blobs
  (`idbloader.img`/`uboot.img`/`trust.img`) in `post-createfs.sh` are the
  right approach for this fork, not a simplification opportunity.
- `uboot/boot.env`'s memory addresses (`fdt_addr_r`, `kernel_addr_r`,
  `ramdisk_addr_r`, `scriptaddr`) are now RK3308's real values, pulled from
  the `CONFIG_ARM64` branch of `ENV_MEM_LAYOUT_SETTINGS` in that build's
  `include/configs/rk3308_common.h`.

Also resolved by inspecting Phase 0's build output: `idbloader.img`
(126 KiB), `uboot.img` (1 MiB) and `trust.img` (1 MiB) all fit comfortably
in the gaps `fwup_include/fwup-common.conf` reserves for them
(32K-8M, 8M-12M, 12M-15M), so no partition collision there. Phase 0's
`sdcard.img` itself has not been boot-tested on real hardware yet.

UART0 console is enabled directly in the ported ROCK Pi S base device tree;
no runtime device-tree overlay is required.

Resolved by actually getting `mix firmware` to complete (each was a real
build failure, fixed and documented in `nerves_defconfig`/patches, not
speculative):

- `BR2_PACKAGE_LIBMNL=y` and `BR2_PACKAGE_LIBNL=y` -- both required by
  `nerves_pack` (netlink hotplug + WiFi), not optional networking cruft.
- `libnl` 3.12.0 wouldn't compile: Buildroot's `linux.mk` unconditionally
  re-runs `headers_install` from *our* ~2016-era RK3308 kernel fork into
  the staging sysroot, clobbering the external toolchain's complete
  headers with incomplete ones (missing newer `linux/ila.h` netlink
  attributes). No Config.in toggle disables this, so `libnl` gets its own
  private, complete copy of that one header instead (`patches/libnl/`).
- `post-createfs.sh` wasn't copying `fwup_include/` into the packaged
  artifact's images dir, so `fwup.conf`'s `include()` of
  `fwup-common.conf` failed at app-build time. Fixed.
- Running `mix firmware` *inside this system project* always "fails" at
  the very end (`scrub-otp-release.sh`, host/target ERTS architecture
  mismatch) -- Nerves incorrectly tries to release the system project
  itself as an application. This is expected/harmless: the actual
  Buildroot artifact (kernel, U-Boot, rootfs, fwup.conf, etc.) finishes
  building successfully before that point. Use a real companion app (like
  `../rockpi_s_smoke_test`) to get an actual bootable `.fw`.

The application-data partition mounts at `/root`, and A/B updates stage the
inactive slot's rootfs, kernel, and device tree before switching slots. This
was verified on hardware with A-to-B and B-to-A Ethernet uploads, automatic
validation, and persistence reboots.

The validated ROCK Pi S is the variant without a populated wireless module,
so this target disables its WLAN, Bluetooth, and associated SDIO nodes. The
alternate `rk3308-rock-pi-s-wireless.dtb` enables the AP6212 combo module for
wireless board variants. Ethernet is the supported interface on this target.

## Plan

1. ~~Validate the boot chain without Nerves first~~ -- done. Phase 0
   (`../buildroot.rockchip.ext`'s `rockpis_defconfig`) builds cleanly with
   the same U-Boot/ATF/kernel/DT pins this system uses.
2. ~~Build this system and fix Buildroot/fwup errors~~ -- done, via the
   `../rockpi_s_smoke_test` companion app. `mix firmware` produces a real
   `.fw`.
3. ~~Burn to an SD card and confirm it boots to an IEx console~~ -- done on
   real ROCK Pi S hardware with Linux 5.10.209 and UART0 at 115200n8.
4. ~~Confirm full A/B firmware updates~~ -- done in both directions over
   Ethernet, including per-slot kernel/device-tree selection and validation.
5. Once this boots reliably, adapt it for the ROCK S Core (rCore) SoM.

## Layout

See `fwup_include/fwup-common.conf` for the full partition/offset diagram.

## License

Licensed under the Apache License, Version 2.0 (see `LICENSE`), consistent
with the rest of the Nerves ecosystem.

`board/` and `package/rkbin/` pull in Rockchip's binary DDR init, ATF BL31,
and miniloader blobs (via [`radxa/rkbin`](https://github.com/radxa/rkbin)).
These are unmodified, closed-source vendor binaries redistributed as-is --
the same binaries already publicly distributed by Radxa and Rockchip -- and
are not covered by this project's license.

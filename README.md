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
  source for the Nerves-specific architecture: boot-from-rootfs (no separate
  FAT boot partition), the baked U-Boot environment / A-B switching logic,
  and the fwup partition layout pattern.

## Status: builds a complete .fw, not yet boot-tested on hardware

`mix firmware` succeeds end-to-end for a companion app
(`../rockpi_s_smoke_test`), producing a real `.fw` file via `fwup`. This is
the first complete Nerves firmware build for the RK3308 -- nothing like it
existed before this. What's *not* yet proven is that it boots: no ROCK Pi S
hardware has been available to test on. Treat everything below as "builds
cleanly" rather than "known correct."

What's carried over **verbatim from the known-working plain-Buildroot
config** (high confidence):

- U-Boot source/pin: `radxa/u-boot.git` @ `233a23e3ed0b3e5250253ee455c3c5df2080f99c`, `rock-pi-s-rk3308` defconfig
- Kernel source/pin: `piter75/rockchip-kernel.git` @ `6c923e306e11a9fa60bae4c319bdb0da9ba38f08`, `rk3308_linux` defconfig, in-tree DTS `rockchip/rk3308-rock-pi-s`
- Rockchip blobs: DDR init, ATF bl31, miniloader (`board/`), and the `rkbin` package providing `loaderimage`/`trust_merger` (`package/rkbin/`)
- Boot-ROM-mandated flash offsets: idbloader@32K, uboot.img@8M, trust.img@12M (from `buildroot.rockchip.ext/board/RK3308/genimage.cfg`)

What's **adapted from a working Nerves system for a different chip**
(medium confidence -- the pattern is proven, the RK3308-specific values
aren't):

- Boot-from-rootfs architecture: kernel Image, device tree and boot vars
  install straight into the squashfs rootfs's `/boot`
  (`BR2_LINUX_KERNEL_INSTALL_TARGET` + `rootfs_overlay/boot/vars.txt`), and
  `uboot/boot.env` loads them from there via `load mmc` -- no separate FAT
  boot partition, no hand-generated `boot.scr`.
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

UART0 console: the original plain-Buildroot config enables it via a
`rk3308-uart0` DT overlay. That overlay is in-tree in the kernel source
(confirmed present in the Phase 0 build output) -- `BR2_LINUX_KERNEL_
DTB_OVERLAY_SUPPORT` enables *compiling* it, but Buildroot doesn't install
overlays into the target on its own, so `post-build.sh` now copies them
into `/boot`, and `rootfs_overlay/boot/vars.txt` sets
`overlays=rk3308-uart0` to load it. Not build-tested yet.

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

What's **still genuinely unresolved**:

- Nobody has booted this on real hardware yet.

## Plan

1. ~~Validate the boot chain without Nerves first~~ -- done. Phase 0
   (`../buildroot.rockchip.ext`'s `rockpis_defconfig`) builds cleanly with
   the same U-Boot/ATF/kernel/DT pins this system uses.
2. ~~Build this system and fix Buildroot/fwup errors~~ -- done, via the
   `../rockpi_s_smoke_test` companion app. `mix firmware` produces a real
   `.fw`.
3. **Burn to an SD card and confirm it boots to an IEx console** (ttyS0,
   115200n8) on real ROCK Pi S / rCore hardware. This is the actual
   unblocking step now -- everything above is "builds," not "works."
4. Confirm A/B firmware updates work (`mix firmware.upgrade`), which
   exercises the `uboot_setenv` logic in `fwup.conf.eex`.
5. Once this boots reliably, adapt it for the ROCK S Core (rCore) SoM.

## Layout

See `fwup_include/fwup-common.conf` for the full partition/offset diagram.

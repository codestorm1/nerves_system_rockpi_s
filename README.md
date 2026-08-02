# nerves_system_rockpi_s

[Nerves](https://nerves-project.org/) system for the [Radxa ROCK Pi S](https://wiki.radxa.com/RockpiS)
(RK3308, aarch64 Cortex-A35). There is no official Nerves system for the
RK3308, or any Rockchip SoC, yet -- this is a from-scratch port.

## Status

Boots reliably on real ROCK Pi S hardware: Linux 5.10.209, squashfs root,
Erlang/OTP 27 to an IEx console. Verified working:

- UART0 console at 115200n8 throughout boot
- Ethernet at 100 Mbps
- Userspace GPIO (`Circuits.GPIO`)
- Full A/B firmware updates over Ethernet, in both directions, including
  automatic validation and persistence across reboots
- Hardware watchdog, I2C1, I2S receive, SPI2 (`/dev/spidev2.0`)

Not yet done: the wireless (AP6212 Wi-Fi/BT) board variant is wired up in
the device tree but untested -- only the no-wireless variant has been run
on hardware. The ROCK S Core (rCore) SoM is unsupported.

## Requirements

- asdf, Elixir/Erlang and `fwup` per `.tool-versions`
- A Linux host to run Buildroot (see the
  [Nerves installation guide](https://hexdocs.pm/nerves/installation.html)
  for the usual native build dependencies)

## Usage

This is a Nerves system, meant to be a dependency of a Nerves application
rather than built standalone. In your app's `mix.exs`:

```elixir
{:nerves_system_rockpi_s, github: "codestorm1/nerves_system_rockpi_s", runtime: false, targets: :rockpi_s}
```

Then, from the application:

```sh
export MIX_TARGET=rockpi_s
mix deps.get
mix firmware
```

`mix firmware` inside *this* repo alone will always fail at the final
`scrub-otp-release.sh` step -- Nerves tries to release the system project
itself as an application, which doesn't apply here. The Buildroot artifact
(kernel, U-Boot, rootfs, `fwup.conf`) finishes building successfully before
that point; a real companion application is what turns it into a bootable
`.fw`.

## Provenance

This port combines two working references:

- [`buildroot.rockchip.ext`](https://github.com/flatmax/buildroot.rockchip) -- a plain
  Buildroot external tree Radxa has confirmed boots on this exact hardware.
  Source for the RK3308-specific boot chain: U-Boot/kernel pins, Rockchip
  blobs, and the boot-ROM-mandated flash offsets (idbloader@32K,
  uboot.img@8M, trust.img@12M).
- [`nerves_system_radxa_cm3`](https://github.com/sportalliance/nerves_system_radxa_cm3) --
  a working Nerves system for a *different* Rockchip SoC (RK3566). Source
  for the Nerves-specific A/B switching logic and fwup partition layout
  pattern (`uboot/boot.env`, `fwup.conf.eex` / `fwup_include/fwup-common.conf`).

Boot chain pins, all inherited from the known-working plain-Buildroot config:

- U-Boot: `radxa/u-boot.git` @ `233a23e3ed0b3e5250253ee455c3c5df2080f99c`, `rock-pi-s-rk3308` defconfig
- Kernel: `radxa/kernel.git` branch `linux-5.10-gen-rkr8-buildroot`, `rk3308_linux` defconfig
- Rockchip blobs: DDR init, ATF BL31, miniloader (`board/`), plus the
  `rkbin` package providing `loaderimage`/`trust_merger` (`package/rkbin/`)

Device tree: this target selects `rockchip/rk3308-rock-pi-s-no-wireless`.
The base tree ships both a `-no-wireless` and a `-wireless` DTS (the latter
enabling the AP6212 combo module) for boards with a populated wireless
module; only the no-wireless variant is hardware-validated so far. UART0 is
enabled directly in the base tree -- no runtime device-tree overlay needed.

Partition layout: FAT boot partition (per-slot kernel Images, device trees,
`boot.scr`), followed by Nerves A/B squashfs root partitions and an
application-data partition mounted at `/root`. See
`fwup_include/fwup-common.conf` for the full partition/offset diagram.

## Roadmap

1. Validate the wireless board variant on real hardware.
2. Port to the ROCK S Core (rCore) SoM.

## License

Licensed under the Apache License, Version 2.0 (see `LICENSE`), consistent
with the rest of the Nerves ecosystem.

`board/` and `package/rkbin/` pull in Rockchip's binary DDR init, ATF BL31,
and miniloader blobs (via [`radxa/rkbin`](https://github.com/radxa/rkbin)).
These are unmodified, closed-source vendor binaries redistributed as-is --
the same binaries already publicly distributed by Radxa and Rockchip -- and
are not covered by this project's license.

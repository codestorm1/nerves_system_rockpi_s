defmodule NervesSystemRockpiS.MixProject do
  use Mix.Project

  @app :nerves_system_rockpi_s
  @version Path.join(__DIR__, "VERSION")
           |> File.read!()
           |> String.trim()

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.17",
      compilers: Mix.compilers() ++ [:nerves_package],
      nerves_package: nerves_package(),
      description: description(),
      deps: deps(),
      aliases: [
        loadconfig: [&bootstrap/1],
        generate_fwup_conf: &generate_fwup_conf/1
      ]
    ]
  end

  def application do
    []
  end

  defp bootstrap(args) do
    set_target()
    Application.start(:nerves_bootstrap)
    Mix.Task.run("loadconfig", args)
  end

  defp nerves_package do
    [
      type: :system,
      artifact_sites: [
        {:github_releases, "codestorm1/nerves_system_rockpi_s"}
      ],
      build_runner_opts: build_runner_opts(),
      platform: Nerves.System.BR,
      platform_config: [
        defconfig: "nerves_defconfig"
      ],
      env: [
        {"TARGET_ARCH", "aarch64"},
        {"TARGET_CPU", "cortex_a35"},
        {"TARGET_OS", "linux"},
        {"TARGET_ABI", "gnu"},
        {"TARGET_GCC_FLAGS",
         "-mabi=lp64 -fstack-protector-strong -mcpu=cortex-a35 -fPIE -pie -Wl,-z,now -Wl,-z,relro"}
      ],
      checksum: package_files()
    ]
  end

  defp deps do
    [
      {:nerves, "~> 1.11", runtime: false},
      {:nerves_system_br, "1.34.0", runtime: false},
      {:nerves_toolchain_aarch64_nerves_linux_gnu, "~> 15.3.0", runtime: false}
    ]
  end

  defp description do
    """
    Nerves System - Radxa ROCK Pi S (RK3308)
    """
  end

  defp package_files do
    [
      "board",
      "package",
      "rootfs_overlay",
      "busybox.fragment",
      "Config.in",
      "external.mk",
      "fwup.conf.eex",
      "fwup_include",
      "known_good",
      "linux.fragment",
      "mix.exs",
      "nerves_defconfig",
      "patches",
      "post-build.sh",
      "post-createfs.sh",
      "uboot",
      "uboot.fragment",
      "VERSION"
    ]
  end

  defp build_runner_opts() do
    # Skip "legal-info": this kernel fork predates the SPDX-style
    # LICENSES/ directory buildroot's linux.mk expects for it, so it
    # fails trying to copy a license file that doesn't exist here. It's
    # a compliance-report step with no effect on the firmware itself.
    # The old Radxa U-Boot tree has produced intermittent host compiler
    # SIGBUS failures at Buildroot's automatic -j17 on the bring-up host.
    # Four jobs has been verified with a clean U-Boot rebuild and still keeps
    # the build reasonably parallel.
    [make_args: primary_site() ++ ["PARALLEL_JOBS=4", "source", "all"]]
  end

  defp primary_site() do
    case System.get_env("BR2_PRIMARY_SITE") do
      nil -> []
      primary_site -> ["BR2_PRIMARY_SITE=#{primary_site}"]
    end
  end

  defp set_target() do
    if function_exported?(Mix, :target, 1) do
      apply(Mix, :target, [:target])
    else
      System.put_env("MIX_TARGET", "target")
    end
  end

  defp generate_fwup_conf(_args) do
    template_path = Path.join(__DIR__, "fwup.conf.eex")
    output_path = Path.join(__DIR__, "fwup.conf")

    Mix.shell().info("Generating fwup.conf")

    content = EEx.eval_file(template_path)
    File.write!(output_path, content)
    Mix.shell().info("Successfully generated #{output_path}")
  end
end

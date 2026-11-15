# kronii's GPUs and cooling.
#
# The Tesla V100 (11:00.0) is a passive datacenter card: it has no fan of its
# own and relies entirely on chassis airflow. The Arc Pro B60 (e3:00.0) stays
# on xe; its own fan is firmware-controlled. The chassis fans follow a
# temperature curve over the hottest of CPU, B60, board and NVIDIA sensors
# (fanctl-config.sh), unless fantui pins a channel to a fixed speed or hands
# it back to the BIOS.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # fanctl's config is generated at start: which hwmonN the Super I/O lands
  # on, and how many pwm channels it has, is only known at runtime.
  fanctlConfig = "/run/fanctl/fanctl.yml";
  fanctlLevels = "/var/lib/fanctl/levels.json";
  # The NVIDIA driver has no hwmon node, so fanctl-nvidia-temp below publishes
  # the hottest NVIDIA card's temperature here in hwmon's millidegree format.
  nvidiaTemp = "/run/fanctl/nvidia/temp1_input";
  writeFanctlConfig = pkgs.writeShellScript "fanctl-config" ''
    export JQ=${lib.getExe pkgs.jq} LEVELS=${fanctlLevels} OUT=${fanctlConfig} NVIDIA_TEMP=${nvidiaTemp}
    # Seed the NVIDIA reading so the first fanctl iteration can't fail on a
    # missing file; the publisher overwrites it within seconds.
    if [ ! -e ${nvidiaTemp} ]; then
      mkdir -p ${dirOf nvidiaTemp}
      echo 60000 > ${nvidiaTemp}
    fi
    exec ${pkgs.bash}/bin/bash ${./fanctl-config.sh}
  '';
  # With every channel on "auto" there's nothing for fanctl to do: skip the
  # unit (fans stay on the BIOS curve) instead of failing it.
  anyManual = pkgs.writeShellScript "fanctl-any-manual" ''
    for p in /sys/class/hwmon/hwmon*/pwm[0-9]; do
      [ -e "$p" ] || continue
      case "$(cat "$(dirname "$p")/name")" in nct6*) ;; *) continue ;; esac
      l=$(${lib.getExe pkgs.jq} -r --arg p "$(basename "$p")" '.[$p] // "curve"' ${fanctlLevels} 2>/dev/null || echo curve)
      [ "$l" = auto ] || exit 0
    done
    # No channels at all is a real problem; let the config step report it.
    ls /sys/class/hwmon/hwmon*/pwm[0-9] >/dev/null 2>&1 || exit 0
    exit 1
  '';
  fantui = pkgs.writers.writePython3Bin "fantui" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./fantui.py);
in
{
  # Volta isn't supported by the open kernel modules or by drivers after the
  # 580 branch, so this skips functorOS.system.graphics.nvidia (open, latest)
  # and sets the driver up directly. Listing "nvidia" here is what turns the
  # NixOS nvidia module on (and blacklists nouveau); X itself stays off.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    open = false;
    modesetting.enable = true;
    nvidiaSettings = false;
    # Headless: keep the driver initialised so the card drops to its idle
    # P-state instead of sitting at boot clocks between jobs.
    nvidiaPersistenced = true;
  };

  # The board's chassis/CPU fan headers are on the Nuvoton Super I/O. ASUS only
  # exposes it through WMI on boards nct6775 allowlists, and the TRX50-SAGE
  # isn't one, so the driver needs the ACPI resource check relaxed to claim
  # the ports directly. asus-ec-sensors (already loaded) only reads the
  # EC-attached fans and can't drive them.
  boot.kernelModules = [ "nct6775" ];
  boot.kernelParams = [ "acpi_enforce_resources=lax" ];

  # Polls nvidia-smi every 5 s and writes the hottest card's temperature where
  # fanctl can read it. If nvidia-smi fails it writes 95 °C, which pushes the
  # curve to full speed rather than letting a passive card cook unnoticed.
  systemd.services.fanctl-nvidia-temp = {
    description = "NVIDIA GPU temperature for fanctl";
    wantedBy = [ "multi-user.target" ];
    after = [ "nvidia-persistenced.service" ];
    serviceConfig = {
      RuntimeDirectory = "fanctl/nvidia";
      RuntimeDirectoryPreserve = "yes";
      Restart = "always";
      RestartSec = 5;
      ExecStart = pkgs.writeShellScript "fanctl-nvidia-temp" ''
        while true; do
          t=$(${config.hardware.nvidia.package.bin}/bin/nvidia-smi \
                --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null \
              | sort -n | tail -1)
          case "$t" in
            ''' | *[!0-9]*) t=95 ;;
          esac
          echo "$((t * 1000))" > ${nvidiaTemp}.tmp
          mv -f ${nvidiaTemp}.tmp ${nvidiaTemp}
          sleep 5
        done
      '';
    };
  };

  # Chassis fans on the temperature curve, or wherever fantui pinned them.
  # Stopping fanctl hands the fans back to the BIOS curve; if it crashes they
  # stay where they were until it restarts.
  systemd.services.fanctl = {
    description = "Chassis fans on a temperature curve (fanctl)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "systemd-modules-load.service"
      "fanctl-nvidia-temp.service"
    ];
    serviceConfig = {
      RuntimeDirectory = "fanctl";
      RuntimeDirectoryPreserve = "yes";
      StateDirectory = "fanctl";
      ExecCondition = anyManual;
      ExecStartPre = writeFanctlConfig;
      ExecStart = "${lib.getExe pkgs.fanctl} -c ${fanctlConfig}";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # `fantui` (re-runs itself under run0) to set per-channel speeds.
  environment.systemPackages = [
    pkgs.fanctl
    fantui
  ];
}

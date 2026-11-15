# osaka's GPUs and cooling.
#
# The Tesla V100 (11:00.0) is a passive datacenter card: it has no fan of its
# own and relies entirely on chassis airflow, so the case fans run flat out.
# The Arc Pro B60 (e3:00.0) stays on xe; its fan is firmware-controlled.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # fanctl's config is generated at start: which hwmonN the Super I/O lands
  # on, and how many pwm channels it has, is only known at runtime. Per-channel
  # targets come from fantui's levels file: a percentage, or "auto" to leave
  # the channel on the BIOS curve. Channels it doesn't list run at 100%.
  fanctlConfig = "/run/fanctl/fanctl.yml";
  fanctlLevels = "/var/lib/fanctl/levels.json";
  jq = lib.getExe pkgs.jq;
  # Prints a channel's target as a 0-1 fraction, or "auto". 20% is the floor
  # (as in fantui): the V100 has no fan of its own.
  levelOf = ''
    level() {
      ${jq} -r --arg p "$1" '.[$p] // 100
        | if . == "auto" then "auto"
          elif type == "number" then ([[., 20] | max, 100] | min) / 100
          else 1 end' ${fanctlLevels} 2>/dev/null || echo 1
    }
  '';
  writeFanctlConfig = pkgs.writeShellScript "fanctl-config" ''
    set -eu
    ${levelOf}
    # "hwmonN:pwmM" for every Super I/O pwm channel fanctl should drive
    fans=""
    found=0
    for h in /sys/class/hwmon/hwmon*; do
      case "$(cat "$h/name")" in
        nct6*) ;;
        *) continue ;;
      esac
      for p in "$h"/pwm[0-9]; do
        [ -e "$p" ] || continue
        found=1
        [ "$(level "$(basename "$p")")" = auto ] && continue
        fans="$fans $(basename "$h"):$(basename "$p")"
      done
    done
    if [ "$found" = 0 ]; then
      echo "fanctl: no nct6775 pwm channels under /sys/class/hwmon; is nct6775 loaded?" >&2
      exit 1
    fi
    {
      printf 'interval: 2000\ninputs: {}\noutputs:\n'
      for f in $fans; do
        h=''${f%%:*} p=''${f#*:}
        printf '  %s_%s:\n    PwmFan:\n      path: %s\n      name: %s\n' \
          "$h" "$p" "$(readlink -f "/sys/class/hwmon/$h")" "$p"
      done
      printf 'rules:\n'
      for f in $fans; do
        h=''${f%%:*} p=''${f#*:}
        printf '  - outputs:\n      - %s_%s\n    rule:\n      Static: %s\n' \
          "$h" "$p" "$(level "$p")"
      done
    } > ${fanctlConfig}
  '';
  # With every channel on "auto" there's nothing for fanctl to do: skip the
  # unit (fans stay on the BIOS curve) instead of failing it.
  anyManual = pkgs.writeShellScript "fanctl-any-manual" ''
    ${levelOf}
    for p in /sys/class/hwmon/hwmon*/pwm[0-9]; do
      [ -e "$p" ] || continue
      case "$(cat "$(dirname "$p")/name")" in nct6*) ;; *) continue ;; esac
      [ "$(level "$(basename "$p")")" = auto ] || exit 0
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

  # Every Super I/O pwm channel pinned at its fantui target (100% by default).
  # Stopping fanctl hands the fans back to the BIOS curve; if it crashes they
  # stay where they were until it restarts.
  systemd.services.fanctl = {
    description = "Motherboard fans at fixed speeds (fanctl)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      RuntimeDirectory = "fanctl";
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

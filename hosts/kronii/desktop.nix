# kronii as a desktop, set up like shirakami-fubuki: niri with the functorOS
# rice, the same keyd remaps, the Steinberg IXO22, Steam. The monitors hang off
# the Arc Pro B60 (xe) for now, both on DisplayPort: the ASUS VG34VQL3A
# ultrawide on DP-4 and the ASUS VG249 (1080p) on DP-1. When the Arc leaves and
# they move to the RTX 3050, the connector names here change
# (`niri msg outputs` lists them). Login goes through functorOS's greeter, ly,
# at its defaults (below).
#
# As of 2026-11-15 the kernel offers the ultrawide nothing above 1920x1080: its
# EDID advertises 3440x1440, so the DP link isn't training at full rate (cable,
# or the port). niri falls back to the preferred mode until that is sorted.
inputs:
{
  pkgs,
  lib,
  ...
}:
{
  functorOS = {
    # functorOS's greeter (ly) at its defaults, themed from stylix; it offers
    # scroll and niri from displayManager.sessionPackages.
    desktop.greeter.enable = true;
    extras.gaming.enable = true;
    # Not functorOS's nvidia setup (open kernel modules, latest driver): the V100
    # needs the legacy 580 branch, which cooling.nix configures directly.
    system.graphics.nvidia.enable = false;
  };
  programs.steam.enable = true;

  functorOS.desktop.scroll.enable = true;

  # Media and compute on the Arc (VAAPI/QSV through iHD, oneVPL, OpenCL). The
  # NVIDIA side is cooling.nix.
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    vpl-gpu-rt
    intel-compute-runtime
  ];
  # Firmware for the Arc, the IMC Networks bluetooth radio and the rest.
  hardware.enableRedistributableFirmware = true;

  # The IXO22's asynchronous USB feedback can lock far below its 48 kHz rate.
  boot.extraModprobeConfig = ''
    options snd_usb_audio lowlatency=0
  '';
  security.rtkit.enable = true;

  # The same remaps as shirakami, on every keyboard (the Keychron Q1 HE here).
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main = {
          capslock = "esc";
          leftalt = "leftcontrol";
          leftcontrol = "leftalt";
          y = "z";
          z = "y";
          esc = "`";
        };
      };
    };
  };

  # Builds and prints run unattended; a brushed power button must not end them.
  services.logind.settings.Login.HandlePowerKey = "ignore";
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  programs.xwayland.enable = true;

  # niri + NVIDIA is known to leak VRAM into a free buffer pool
  # (https://github.com/niri-wm/niri/wiki/Nvidia); cap the reuse ratio. Idle
  # while niri renders on the Arc, needed once the 3050 drives the monitors.
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
    builtins.toJSON {
      rules = [
        {
          pattern = {
            feature = "procname";
            matches = "niri";
          };
          profile = "Limit Free Buffer Pool On Wayland Compositors";
        }
      ];
      profiles = [
        {
          name = "Limit Free Buffer Pool On Wayland Compositors";
          settings = [
            {
              key = "GLVidHeapReuseRatio";
              value = 0;
            }
          ];
        }
      ];
    };

  home-manager.users.kaitotlex = {
    # No EasyEffects, as on shirakami.
    functorOS.utils.audio.enable = false;

    programs.dank-material-shell.settings = {
      acMonitorTimeout = lib.mkForce 0;
      acSuspendTimeout = lib.mkForce 0;
      lockBeforeSuspend = lib.mkForce false;
    };

    systemd.user.services.xwayland-satellite = {
      Unit = {
        Description = "Xwayland outside your Wayland";
        BindsTo = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        Requisite = [ "graphical-session.target" ];
        ConditionEnvironment = "XDG_CURRENT_DESKTOP=niri";
      };
      Service = {
        Type = "notify";
        NotifyAccess = "all";
        ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite";
        StandardOutput = "journal";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
    systemd.user.sessionVariables.DISPLAY = ":0";

    # The ultrawide is the main screen, the 1080p sits to its right, centred
    # vertically. No refresh rate: niri takes the highest one for the mode.
    programs.niri.settings.outputs = {
      "DP-4" = {
        mode = {
          width = 3440;
          height = 1440;
        };
        position = {
          x = 0;
          y = 0;
        };
        focus-at-startup = true;
      };
      "DP-1" = {
        mode = {
          width = 1920;
          height = 1080;
        };
        position = {
          x = 3440;
          y = 180;
        };
      };
    };
  };
}

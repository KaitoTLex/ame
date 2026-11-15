# GPUs and displays: NVIDIA PRIME offload beside the AMD GPU, the niri VRAM
# leak cap, LACT for the AMD side, Xwayland for the X11-only tools, and the
# monitor layout.
{
  pkgs,
  ...
}:
{
  # services.supergfxd.enable = true;
  # environment.systemPackages = [ pkgs.supergfxctl ];
  services.lact.enable = true;
  hardware.amdgpu.overdrive.enable = true;

  # functorOS.system.graphics.nvidia.enable (set below) already configures
  # modesetting/powerManagement/nvidiaSettings/open/the driver package and
  # hardware.graphics.enable, so only PRIME bus wiring needs to happen here.
  #
  # functorOS declares nvidia.optimus-prime.enable/powerMode but does not
  # wire them to anything yet (checked modules/linux/graphics/default.nix,
  # rev 61d2323), so PRIME is still configured via hardware.nvidia.prime
  # directly. `sync`/`reverseSync` only work under Xorg and are a silent
  # no-op under niri (pure Wayland, no X server driving the session) -
  # `offload` is the mode that actually works with Wayland compositors.
  hardware.nvidia.prime = {
    nvidiaBusId = "PCI:1:0:0";
    amdgpuBusId = "PCI:16:0:0";
    offload = {
      enable = true;
      enableOffloadCmd = true;
    };
  };

  # niri + NVIDIA is known to leak VRAM into a free buffer pool
  # (https://github.com/niri-wm/niri/wiki/Nvidia); cap the reuse ratio.
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

  programs.xwayland.enable = true;

  home-manager.users.kaitotlex = {
    systemd.user.services.xwayland-satellite = {
      Unit = {
        Description = "Xwayland outside your Wayland";
        BindsTo = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        Requisite = [ "graphical-session.target" ];
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
    programs.niri.settings.outputs."Microstep MSI G274 CC2H032401304" = {
      mode = {
        width = 1920;
        height = 1080;
        refresh = 165.001;
      };
      position = {
        x = 0;
        y = 0;
      };
      focus-at-startup = true;
    };

    #programs.dank-material-shell.settings = lib.mkForce {
    #  batteryChargeLimit = 98;
    #};
    #programs.niri.settings = {
    #  input.touchpad.tap = lib.mkForce true;
    #  outputs = {
    #     "Acer Technologies QG221Q TGGTT0018512" = {
    #       mode = {
    #         width = 1920;
    #         height = 1080;
    #         refresh = 60.0;
    #       };
    #       transform.rotation = 270;
    #       position = {
    #         x = 1920;
    #        y = 0;
    #};
    #};
  };
}

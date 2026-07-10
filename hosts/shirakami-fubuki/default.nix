inputs:
{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.corecycler.nixosModules.default
    #    inputs.npu.nixosModules.default
  ];

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      timeout = 15;
      systemd-boot.enable = lib.mkForce false;
    };
    kernelPackages = pkgs.linuxPackages_zen;
    kernelModules = [ "uinput" ];
    kernelParams = [ "amd_pstate=active" ];
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };

  # services.supergfxd.enable = true;
  hardware.opentabletdriver.enable = true;
  hardware.uinput.enable = true;
  services.corecycler = {
    enable = true;
    deviceAccessUser = "kaitotlex"; # required -- grants MSR/SMU access without sudo
    unfreeBackends = true; # include mprime (best for CO tuning)
    # Ryzen 7 7800X3D (Zen 4, single CCD, 8 cores/16 threads, V-Cache) on an
    # ASUS/MSI/ASRock board -- Nuvoton Super I/O, not ITE.
    zenpower = true; # zenpower5: SVI2 voltage + RAPL power, richer than k10temp
    nct6775 = true; # Nuvoton Super I/O -- Vcore/fan/temp (most ASUS/MSI/ASRock boards)
    nct6683 = true; # newer Nuvoton chip variant on some MSI boards; no-op if not present
    spd5118 = true; # AM5 is DDR5-only -- DIMM temps via the SPD hub
  };

  services.lact.enable = true;
  hardware.amdgpu.overdrive.enable = true;

  environment.systemPackages = with pkgs; [
    ryzenadj
    linuxPackages_zen.cpupower
    stress-ng
  ];

  nixpkgs.config.allowUnfree = true;

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

  # environment.systemPackages = [ pkgs.supergfxctl ];

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

  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
  };
  programs.xwayland.enable = true;

  nixpkgs.overlays = lib.mkAfter [
    inputs.nix-xilinx.overlay
  ];
  programs.steam.enable = true;
  functorOS = {
    theming = {
      wallpaper = "${inputs.wallpapers}/anime/plarona.jpg";
      polarity = "dark";
      base16Scheme = ../../scheme/mafuyu.yaml;
    };
    system = {
      networking.firewallPresets.vite = false;
      graphics.nvidia.enable = true;
    };
    extras.gaming = {
      enable = true;
    };
  };
  age.secrets.eduroam.file = ../../modules/secrets/eduroam.age;

  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ config.age.secrets.eduroam.path ];
    profiles.eduroam = {
      connection = {
        id = "eduroam";
        type = "wifi";
        interface-name = "wlp6s0";
      };
      wifi = {
        mode = "infrastructure";
        ssid = "eduroam";
      };
      wifi-security = {
        key-mgmt = "wpa-eap";
      };
      "802-1x" = {
        eap = "peap";
        identity = "ren.lin@sjsu.edu";
        phase2-auth = "mschapv2";
        password = "$EDUROAM_PASSWORD";
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
  };

  #  services.npu = {
  #    enable = true;
  #    role = "client";
  #    root = "/home/kaitotlex/npu";
  #    syncthing.devices = {
  #      kanade = "I7GSJMD-7CONAPR-AIB3KHC-3IWKEF3-XLJJL55-YKS4PEX-U35ULHN-IWPPXAH";
  #    };
  #  };

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
    #programs.dank-material-shell.settings = lib.mkForce {
    #  batteryChargeLimit = 98;
    #};
    #programs.niri.settings = {
    #  input.touchpad.tap = lib.mkForce true;
    #  outputs = {
    #    "Microstep MSI G274 CC2H032401304" = {
    #      mode = {
    #        width = 1920;
    #        height = 1080;
    #        refresh = 165.001;
    #      };
    #      position = {
    #         x = 0;
    #         y = 0;
    #       };
    #       focus-at-startup = true;
    #     };
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

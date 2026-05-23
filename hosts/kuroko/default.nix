inputs:
{ pkgs, lib, ... }:
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      timeout = 15;
      systemd-boot.enable = lib.mkForce false;
    };
    kernelPackages = pkgs.linuxPackages_zen;
    kernelModules = [ "uinput" ];
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };

  services.supergfxd.enable = true;
  hardware.opentabletdriver.enable = true;
  hardware.uinput.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    nvidiaSettings = true;
    open = true;
    prime = {
      nvidiaBusId = "PCI:1:0:0";
      amdgpuBusId = "PCI:8:0:0";
      sync.enable = false;
    };
  };

  environment.systemPackages = [ pkgs.supergfxctl ];

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

  functorOS = {
    theming = {
      wallpaper = "${inputs.wallpapers}/anime/plarona.jpg";
      polarity = "dark";
      base16Scheme = ../../scheme/plana.yaml;
    };
    system = {
      networking.firewallPresets.vite = false;
      graphics.nvidia.enable = true;
    };
    extras.gaming = {
      enable = false;
    };
  };

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
    programs.dank-material-shell.settings = lib.mkForce {
      batteryChargeLimit = 98;
    };
    programs.niri.settings = {
      input.touchpad.tap = lib.mkForce true;
      outputs = {
        "Microstep MSI G274 CC2H032401304" = {
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
        "Acer Technologies QG221Q TGGTT0018512" = {
          mode = {
            width = 1920;
            height = 1080;
            refresh = 60.0;
          };
          transform.rotation = 270;
          position = {
            x = 1920;
            y = 0;
          };
        };
      };
    };
  };
}

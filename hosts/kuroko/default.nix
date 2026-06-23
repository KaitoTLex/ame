inputs:
{ pkgs, lib, config, ... }:
{
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.npu.nixosModules.default
    inputs.agenix.nixosModules.default
  ];

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
      base16Scheme = ../../scheme/mafuyu.yaml;
    };
    system = {
      networking.firewallPresets.vite = false;
      graphics.nvidia.enable = true;
    };
    extras.gaming = {
      enable = false;
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

  services.npu = {
    enable = true;
    role = "client";
    root = "/home/kaitotlex/npu";
    syncthing.devices = {
      kanade = "I7GSJMD-7CONAPR-AIB3KHC-3IWKEF3-XLJJL55-YKS4PEX-U35ULHN-IWPPXAH";
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

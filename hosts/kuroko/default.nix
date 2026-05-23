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

    services.kanshi = lib.mkForce {
      enable = true;
      systemdTarget = "niri.service";
      settings = [
        {
          profile = {
            name = "docked";
            outputs = [
              {
                criteria = "Sharp Corporation LQ134N1JW52 Unknown";
                status = "disable";
              }
              {
                criteria = "Acer Technologies QG221Q TGGTT0018512";
                status = "enable";
                mode = "1920x1080@60";
                transform = "90";
                position = "1920,0";
              }
              {
                criteria = "Microstep MSI G274 CC2H032401304";
                status = "enable";
                mode = "1920x1080@165.001";
                position = "0,0";
              }
            ];
          };
        }
        {
          profile = {
            name = "undocked";
            outputs = [
              {
                criteria = "Sharp Corporation LQ134N1JW52 Unknown";
                status = "enable";
                mode = "1920x1200@120";
                scale = 1.0;
              }
            ];
          };
        }
      ];
    };
  };
}

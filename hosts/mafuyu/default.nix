inputs:
{ pkgs, lib, ... }:
{
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.aagl.nixosModules.default
  ];

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      timeout = 15;
      systemd-boot.enable = lib.mkForce false;
    };
    kernelPackages = pkgs.linuxPackages_zen;
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };

  nixpkgs.overlays = lib.mkAfter [
    inputs.nix-xilinx.overlay
  ];

  environment.systemPackages = [
    pkgs.libfprint
    pkgs.fprintd
    (pkgs.ankiAddons.recolor.withConfig {
      config = {
        colors = {
          ACCENT_CARD = [ ];
        };
        version = {
          major = 3;
          minor = 1;
        };
      };
    })
  ];

  services.fprintd.enable = true;
  hardware.trackpoint.sensitivity = 57;

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
        };
      };
    };
  };

  services.tlp = {
    enable = true;
    settings = {
      STOP_CHARGE_THRESH_BAT0 = 90;
    };
  };

  nix.settings = {
    substituters = [ "https://ezkea.cachix.org" ];
    trusted-public-keys = [ "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI=" ];
  };

  programs.honkers-railway-launcher.enable = true;

  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
  };

  home-manager.users.kaitotlex.programs.niri.settings.outputs."eDP-1" = {
    mode = { width = 1920; height = 1080; refresh = 60.0; };
    scale = 1.0;
  };

  functorOS = {
    theming = {
      wallpaper = "${inputs.wallpapers}/vtubers/ame/ameStudent.jpg";
      polarity = "light";
      base16Scheme = ../../scheme/watson.yaml;
    };
    system = {
      networking.firewallPresets.vite = false;
      graphics.nvidia.enable = false;
    };
    extras.gaming = {
      enable = true;
      roblox.enable = false;
      utilities.gamemode.enable = true;
    };
  };
}

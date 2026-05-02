{
  description = "KaitoTLex's modification to the already functional functorOS";

  inputs = {
    # Follow the nixpkgs in functorOS, which is verified to build properly before release.
    functorOS.url = "github:youwen5/functorOS";
    #functorOS.inputs.apple-firmware.url = "github:binary-star-systems/apple-firmware";
    nixpkgs.follows = "functorOS/nixpkgs";

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    apple-silicon = {
      #url = "github:flokli/nixos-apple-silicon/mainline-mesa";
      url = "github:nix-community/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wallpapers = {
      url = "github:kaitotlex/wallpaper";
      flake = false;
    };
    nixvim = {
      url = "github:kaitotlex/vix1";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-xilinx = {
      # Recommended if you also override the default nixpkgs flake, common among
      # nixos-unstable users:
      #inputs.nixpkgs.follows = "nixpkgs";
      url = "github:MIT-OpenCompute/xilinx-flake";
    };
    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tmux = {
      url = "github:jakehamilton/tmux";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      self,
      flake-utils,
      functorOS,
      ...
    }:
    let
      functorOSLib = import functorOS {
        inherit
          inputs
          self
          nixpkgs
          functorOS
          ;
      };
      kaitotlex = functorOSLib.user.instantiate {
        username = "kaitotlex";
        homeDirectory = "/home/kaitotlex";
        fullName = "KaitoTLex";
        email = "renl@kaitotlex.systems";
        configureGitUser = true;
        configuration = {
          imports = [
            ./home.nix
          ];
          wayland.windowManager.hyprland.xwayland.enable = true;
          wayland.windowManager.hyprland.settings = {
            monitor = [
              "desc: Microstep MSI G274 CC2H032401304 ,1920x1080@165,0x0,1" # kuroko docked primary
              "desc: Acer Technologies QG221Q TGGTT0018512,1920x1080@60,1920x-600,1,transform,3" # kuroko docked portrait
              "desc: Sharp Corporation LQ134N1JW52,disabled" # kuroko built-in display (disabled when docked)
              # "eDP-1,1920x1200x120,0x0,1"#kuroko/shiroko display conf
              "desc: Lenovo Group Limited 0x40A9,1920x1080x60.02,0x0, 1" # mafuyu display conf
              # "HDMI-A-1, preferred, auto,1" # extrnal connections
              # "eDP-1,3024x1964@120.00,0x0,1.5" # kanade
            ];
          };

          functorOS.desktop.hyprland.screenlocker.useCrashFix = true;
          functorOS.desktop.waybar.variant = "compact";
          functorOS.desktop.hyprland.screenlocker.monitor = "eDP-1";
          home.stateVersion = "25.11";
        };
      };
    in
    {
      nixosConfigurations = {
        kuroko = functorOSLib.system.instantiate {
          hostname = "kuroko";
          users = [ kaitotlex ];

          configuration =
            { pkgs, lib, ... }:
            {
              imports = [
                (import ./commonConfig.nix inputs)
                ./hosts/kuroko/hardware-configuration.nix
                inputs.lanzaboote.nixosModules.lanzaboote
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

              services.supergfxd.enable = true;
              hardware.opentabletdriver.enable = true;
              hardware.uinput.enable = true;
              boot.kernelModules = [ "uinput" ];

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
                    };
                  };
                };
              };

              services.tlp = {
                enable = true;
                settings = {
                  START_CHARGE_THRESH_BAT0 = 20;
                  STOP_CHARGE_THRESH_BAT0 = 98;
                };
              };

              functorOS = {
                theming = {
                  wallpaper = "${inputs.wallpapers}/anime/plana.jpg";
                  polarity = "dark";
                  base16Scheme = ./scheme/plana.yaml;
                };
                system = {
                  networking.firewallPresets.vite = false;
                  graphics.nvidia.enable = true;
                };
                extras.gaming = {
                  enable = true;
                  roblox.enable = true;
                  utilities.gamemode.enable = true;
                };
              };
            };
        };

        mafuyu = functorOSLib.system.instantiate {
          hostname = "mafuyu";
          users = [ kaitotlex ];

          configuration =
            { pkgs, lib, ... }:
            {
              imports = [
                (import ./commonConfig.nix inputs)
                ./hosts/mafuyu/hardware-configuration.nix
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

              functorOS = {
                theming = {
                  wallpaper = "${inputs.wallpapers}/vtubers/ame/ameStudent.jpg";
                  polarity = "light";
                  base16Scheme = ./scheme/watson.yaml;
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
            };
        };

        kanade = functorOSLib.system.instantiate {
          hostname = "kanade";
          users = [ kaitotlex ];

          configuration =
            { pkgs, lib, ... }:
            {
              imports = [
                (import ./commonConfig.nix inputs)
                ./hosts/kanade/hardware-configuration.nix
                inputs.apple-silicon.nixosModules.apple-silicon-support
              ];

              nix.settings = {
                substituters = [ "https://hyprland.cachix.org" ];
                trusted-substituters = [ "https://hyprland.cachix.org" ];
                trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
              };

              boot.kernelModules = [
                "ip_tables"
                "iptable_nat"
                "iptable_filter"
                "iptable_mangle"
              ];
              networking.nftables.enable = true;
              networking.firewall.trustedInterfaces = [ "waydroid0" ];
              services.logind.settings.Login = {
                HandlePowerKey = "ignore";
              };

              boot = {
                loader.systemd-boot.enable = true;
                loader.efi.canTouchEfiVariables = false;
                kernelParams = [ "appledrm.show_notch=1" ];
                extraModprobeConfig = ''
                  options hid_apple iso_layout=0
                '';
              };

              services.udev.extraRules = ''
                KERNEL=="macsmc-battery", SUBSYSTEM=="power_supply", ATTR{charge_control_end_threshold}="90", ATTR{charge_control_start_threshold}="85"
              '';

              hardware.asahi = {
                enable = true;
                peripheralFirmwareDirectory = ./hosts/kanade/firmware;
              };
              virtualisation.waydroid.enable = true;

              services = {
                printing.enable = true;
                avahi = {
                  enable = true;
                  nssmdns4 = true;
                  openFirewall = true;
                };
              };

              nixpkgs.overlays = lib.mkAfter [
                inputs.apple-silicon.overlays.apple-silicon-overlay
                inputs.tmux.overlay
                (final: prev: {
                  waydroid = prev.waydroid.overrideAttrs (old: {
                    postPatch = (old.postPatch or "") + ''
                      sed -i 's/iptables_legacy=.*/iptables_legacy=/' data/scripts/waydroid-net.sh
                    '';
                  });
                })
              ];

              services.keyd = {
                enable = true;
                keyboards.default = {
                  ids = [ "*" ];
                  settings = {
                    main = {
                      capslock = "esc";
                      leftmeta = "leftcontrol";
                      leftalt = "leftmeta";
                      leftcontrol = "leftalt";
                      rightmeta = "leftalt";
                      rightalt = "layer(rightalt)";
                      y = "z";
                      z = "y";
                    };
                  };
                };
              };

              services.tailscale.enable = true;

              functorOS = {
                theming = {
                  wallpaper = "${inputs.wallpapers}/vtubers/sui/nordMachi-retina.png";
                  polarity = "dark";
                  base16Scheme = ./scheme/nord.yaml;
                };
                system = {
                  networking = {
                    firewallPresets.vite = true;
                    backend = "iwd";
                  };
                  graphics.nvidia.enable = false;
                };
                extras.gaming.enable = false;
              };
            };
        };
      };

    };
}

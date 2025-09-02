{
  description = "Minimal standalone functorOS system";

  inputs = {
    # Follow the nixpkgs in functorOS, which is verified to build properly before release.
    functorOS.url = "github:kaitotlex/functorOS";
    nixpkgs.follows = "functorOS/nixpkgs";
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    apple-silicon = {
      #url = "github:flokli/nixos-apple-silicon/mainline-mesa";
      url = "github:nix-community/nixos-apple-silicon";
      #inputs.nixpkgs.follows = "nixpkgs";
    };
    wallpapers = {
      url = "github:kaitotlex/wallpaper";
      flake = false;
    };
    nixvim = {
      url = "github:kaitotlex/vix1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    KaitoianOS = {
      url = "github:kaitotlex/KaitoianOSmod";
      flake = false;
    };

    # Alternatively, pin your own nixpkgs and set functorOS to follow it, as shown below.

    # nixpkgs.follows = "github:nixos/nixpkgs?ref=nixos-unstable";
    # functorOS.url = "github:youwen5/functorOS";
    # functorOS.inputs.nixpkgs.follows = "nixpkgs";

    # Either way, you should ensure that functorOS shares nixpkgs with your
    # system to avoid any weird conflicts.
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
        # Linux username for your user
        username = "kaitotlex";

        # Absolute path to the home directory
        homeDirectory = "/home/kaitotlex";

        # Full name. This is really just the string provided in the
        # `description` field of your Linux user, which is generally the user's
        # full name.
        fullName = "KaitoTLex";

        # Email address of user
        email = "renl@kaitotlex.systems";

        # If you set this to true, Git will automatically be configured with the fullName and email set above.
        configureGitUser = true;

        # This is treated just like a standard `home.nix` home-manager
        # configuration file.
        configuration = {
          # You can set arbitrary options here. For example, if your
          # home-manager configuration is in another file, then import it like
          # so:
          imports = [
            "${inputs.KaitoianOS}/home.nix"
          ];
          # Or any other option, like
          # programs.neovim.enable = true;
          # programs.neovim.settings = { # --snip-- };

          # Let's set the home-manager state version.

          # This value determines the NixOS release from which the default
          # settings for stateful data, like file locations and database versions
          # on your system were taken. It‘s perfectly fine and recommended to leave
          # this value at the release version of the first install of home-manager.
          home.stateVersion = "25.05";
        };
      };
    in
    {
      # Execute sudo nixos-rebuild switch --flake .#functorOS
      nixosConfigurations = {
        kuroko = functorOSLib.system.instantiate {
          hostname = "kuroko";

          # List of users generated with functorOSLib.user.instantiate.
          users = [ kaitotlex ];
          # users.users.kaitotlex = {
          #   isNormalUser = true;
          #   description = "KaitoTLex";
          #   extraGroups = [
          #     "networkmanager"
          #     "wheel"
          #     "disk"
          #     "root"
          #     "audio"
          #   ];
          # };

          # Additional system configuration.
          configuration =
            { pkgs, lib, ... }:
            let
              # Import the KaitoianOSmod package definitions
              kaitoPkgs = import "${inputs.KaitoianOS}/pkgs/default.nix" {
                inherit pkgs;
                system = pkgs.stdenv.targetPlatform.system;
              };
            in
            {

              # This is treated just like a standard configuration.nix file.

              # You can set any arbitrary NixOS options here. For example, don't
              # forget to import hardware-configuration.nix:

              # The included hardware-configuration.nix in this template is a placeholder.
              # The system WILL NOT build until you import your own!

              # You need to import your `hardware-configuration.nix`. If you don't have it,
              # run `nixos-generate-config` and it will be automatically populated at
              # /etc/nixos/hardware-configuration.nix.

              # Simply copy that file over into the same directory as your
              # `flake.nix`, replacing the existing placeholder file.
              imports = [
                ./hosts/kuroko/hardware-configuration.nix
                inputs.lanzaboote.nixosModules.lanzaboote
                "${inputs.KaitoianOS}/hardware"
              ];

              # Set up a bootloader:
              boot = {
                loader = {
                  efi.canTouchEfiVariables = true;
                  timeout = 15;
                  # lanzaboote replaces systemd-boot
                  systemd-boot.enable = lib.mkForce false;
                };

                # (optionally) Select a kernel.
                kernelPackages = pkgs.linuxPackages_zen;
                lanzaboote = {
                  enable = true;
                  pkiBundle = "/var/lib/sbctl";
                };
              };
              services.supergfxd.enable = true;

              hardware.nvidia = {
                modesetting.enable = true;
                powerManagement.enable = true;
                powerManagement.finegrained = false;
                nvidiaSettings = true;
                open = true;
                prime = {
                  nvidiaBusId = "PCI:1:0:0";
                  amdgpuBusId = "PCI:8:0:0";
                  # offload = {
                  #   enable = true;
                  #   enableOffloadCmd = true;
                  # };
                  sync.enable = false;
                };
              };
              nixpkgs.config.allowUnfree = true;
              environment.systemPackages = [
                inputs.nixvim.packages.${pkgs.stdenv.targetPlatform.system}.default
                pkgs.supergfxctl
              ]
              ++ kaitoPkgs;
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
              wayland.windowManager.hyprland.settings.env = [
                "AQ_DRM_DEVICES,/dev/dri/card2:/dev/dri/card1"
              ];

              wayland.windowManager.hyprland.settings = {
                monitor = [
                  "eDP-1,disable"
                  "HDMI-A-1,1920x1080@165,0x0,1"
                  "DP-2,1920x1080@60,1920x-600,1,transform,3"
                ];
              };
              services.tlp = {
                enable = true;
                settings = {
                  #Optional helps save long term battery health
                  START_CHARGE_THRESH_BAT0 = 20; # 40 and bellow it starts to charge
                  STOP_CHARGE_THRESH_BAT0 = 98; # 80 and above it stops charging

                };
              };

              time.timeZone = "America/Los_Angeles";

              # Make sure to set the state version of your NixOS install! Find
              # it in your existing /etc/nixos/configuration.nix.

              # This value determines the NixOS release from which the default
              # settings for stateful data, like file locations and database versions
              # on your system were taken. It‘s perfectly fine and recommended to leave
              # this value at the release version of the first install of this system.
              # Before changing this value read the documentation for this option
              # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
              system.stateVersion = "25.05"; # Did you read the comment?

              # Other options such as
              # hardware.graphics.enable = true
              # work fine here too.

              # -----------------------------------------------------------------------

              # The functorOS option below is a special option generated by
              # functorOS, and used to configure it.

              # Don't panic! Documentation for functorOS.* system options is
              # available at <https://os.functor.systems>
              functorOS = {
                # Set this to the absolute path of the location of this configuration flake
                # to enable some UX enhanacements
                flakeLocation = "/home/kaitotlex/.config/functorOS-config";

                # Allow functorOS's unfree packages
                # This option doesn't set allowUnfree for the whole system,
                # rather, it simply allows a specifically curated list of
                # unfree packages in functorOS
                config.allowUnfree = true;

                # Set your default editor to any program.
                defaultEditor = pkgs.neovim;

                # Set to either "laptop" or "desktop" for some adjustments
                formFactor = "laptop";

                desktop.localization.chinese = {
                  input.enable = true;
                  script = "traditional";
                };

                # Set a wallpaper to whatever you want! You can use a local path as well.
                # The colorscheme for the system is automatically generated from this
                # wallpaper!
                theming = {
                  wallpaper = "${inputs.wallpapers}/anime/mafuyuNightchord.png";
                  polarity = "light";
                  base16Scheme = "${inputs.KaitoianOS}/scheme/mafuyu.yaml";
                };
                system = {
                  # Toggle true to enable audio production software, like
                  # reaper, and yabridge + 64 bit wine for installing
                  # Windows-exclusive VSTs! Also sets realtime kernel
                  # configuration and other optimizations.
                  audio.prod.enable = false;

                  networking = {
                    # Toggle on to allow default vite ports of 5173 and 4173 through the firewall for local testing.
                    firewallPresets.vite = false;
                    # Use cloudflare's 1.1.1.1 DNS servers.
                    cloudflareNameservers.enable = true;
                  };
                  # Set some sane defaults for nvidia graphics, like proprietary drivers.
                  # WARNING: requires functorOS.config.allowUnfree to be set to true.
                  graphics.nvidia.enable = true;
                };
                extras.gaming = {
                  # Enable gaming utilities, like Lutris, Steam, Prism Launcher, etc.
                  enable = true;
                  # Installs Roblox using Sober, as a flatpak. Note that this will enable
                  # the impure flatpak service that automatically updates flatpaks every
                  # week upon nixos-rebuild switch
                  roblox.enable = true;

                  utilities.gamemode = {
                    # Enable the gamemoderun binary to maximize gaming performance
                    enable = true;
                  };
                };
              };
            };
        };
        kanade = functorOSLib.system.instantiate {
          hostname = "kanade";

          # List of users generated with functorOSLib.user.instantiate.
          users = [ kaitotlex ];
          # users.users.kaitotlex = {
          #   isNormalUser = true;
          #   description = "KaitoTLex";
          #   extraGroups = [
          #     "networkmanager"
          #     "wheel"
          #     "disk"
          #     "root"
          #     "audio"
          #   ];
          # };

          # Additional system configuration.
          configuration =
            { pkgs, lib, ... }:
            let
              # Import the KaitoianOSmod package definitions
              kaitoPkgs = import "${inputs.KaitoianOS}/pkgs/default.nix" {
                inherit pkgs;
                system = pkgs.stdenv.targetPlatform.system;
              };
            in
            {

              # This is treated just like a standard configuration.nix file.

              # You can set any arbitrary NixOS options here. For example, don't
              # forget to import hardware-configuration.nix:

              # The included hardware-configuration.nix in this template is a placeholder.
              # The system WILL NOT build until you import your own!

              # You need to import your `hardware-configuration.nix`. If you don't have it,
              # run `nixos-generate-config` and it will be automatically populated at
              # /etc/nixos/hardware-configuration.nix.

              # Simply copy that file over into the same directory as your
              # `flake.nix`, replacing the existing placeholder file.
              imports = [
                ./hosts/kanade/hardware-configuration.nix
                "${inputs.KaitoianOS}/hardware"
              ];

              # Set up a bootloader:
              environment.systemPackages = [
                inputs.nixvim.packages.${pkgs.stdenv.targetPlatform.system}.default
              ]
              ++ kaitoPkgs;
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
              services.tlp = {
                enable = true;
                settings = {
                  #Optional helps save long term battery health
                  START_CHARGE_THRESH_BAT0 = 20; # 40 and bellow it starts to charge
                  STOP_CHARGE_THRESH_BAT0 = 98; # 80 and above it stops charging

                };
              };

              time.timeZone = "America/Los_Angeles";

              # Make sure to set the state version of your NixOS install! Find
              # it in your existing /etc/nixos/configuration.nix.

              # This value determines the NixOS release from which the default
              # settings for stateful data, like file locations and database versions
              # on your system were taken. It‘s perfectly fine and recommended to leave
              # this value at the release version of the first install of this system.
              # Before changing this value read the documentation for this option
              # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
              system.stateVersion = "25.05"; # Did you read the comment?

              # Other options such as
              # hardware.graphics.enable = true
              # work fine here too.

              # -----------------------------------------------------------------------

              # The functorOS option below is a special option generated by
              # functorOS, and used to configure it.

              # Don't panic! Documentation for functorOS.* system options is
              # available at <https://os.functor.systems>
              functorOS = {
                # Set this to the absolute path of the location of this configuration flake
                # to enable some UX enhanacements
                flakeLocation = "/home/kaitotlex/.config/ame";

                # Allow functorOS's unfree packages
                # This option doesn't set allowUnfree for the whole system,
                # rather, it simply allows a specifically curated list of
                # unfree packages in functorOS
                config.allowUnfree = true;

                # Set your default editor to any program.
                defaultEditor = pkgs.neovim;

                # Set to either "laptop" or "desktop" for some adjustments
                formFactor = "laptop";

                desktop.localization.chinese = {
                  input.enable = true;
                  script = "traditional";
                };

                # Set a wallpaper to whatever you want! You can use a local path as well.
                # The colorscheme for the system is automatically generated from this
                # wallpaper!
                theming = {
                  wallpaper = "${inputs.wallpapers}/vtubers/ame/watsonBus.jpg";
                  polarity = "light";
                  base16Scheme = "${inputs.KaitoianOS}/scheme/watson.yaml";
                };
                system = {
                  # Toggle true to enable audio production software, like
                  # reaper, and yabridge + 64 bit wine for installing
                  # Windows-exclusive VSTs! Also sets realtime kernel
                  # configuration and other optimizations.
                  audio.prod.enable = false;

                  networking = {
                    # Toggle on to allow default vite ports of 5173 and 4173 through the firewall for local testing.
                    # Use cloudflare's 1.1.1.1 DNS servers.
                    cloudflareNameservers.enable = false;
                  };
                  # Set some sane defaults for nvidia graphics, like proprietary drivers.
                  # WARNING: requires functorOS.config.allowUnfree to be set to true.
                  graphics.nvidia.enable = false;

                  # Set some asahi options
                  asahi = {
                    enable = true;
                    firmware = ./hosts/kanade/firmware;
                  };
                };
              };
            };
        };
      };

    };
}

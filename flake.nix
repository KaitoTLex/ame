{
  description = "KaitoTLex's modification to the already functional functorOS";
  inputs = {
    # Follow the nixpkgs in functorOS, which is verified to build properly before release.
    # functorOS.url = "git+https://code.functor.systems/kaitotlex/functorOS-prime.git";
    functorOS.url = "github:youwen5/functorOS";
    #functorOS.inputs.apple-firmware.url = "github:binary-star-systems/apple-firmware";
    nixpkgs.follows = "functorOS/nixpkgs";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    functoros-apple-silicon = {
      #url = "github:flokli/nixos-apple-silicon/mainline-mesa";
      url = "github:youwen5/functoros-apple-silicon";
      # url = "github:nix-community/nixos-apple-silicon";
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
      inputs.nixpkgs.follows = "nixpkgs";
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

    npu = {
      url = "path:/home/kaitotlex/npu";
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
          functorOS.desktop.niri.enable = true;
          # functorOS.desktop.hyprland.screenlocker.useCrashFix = true;
          # functorOS.desktop.waybar.variant = "compact";
          # functorOS.desktop.hyprland.screenlocker.monitor = "eDP-1";
          home.stateVersion = "26.05";
        };
      };
    in
    {
      nixosConfigurations = {
        kuroko = functorOSLib.system.instantiate {
          hostname = "kuroko";
          users = [ kaitotlex ];
          configuration =
            { ... }:
            {
              imports = [
                (import ./config.nix inputs)
                ./hosts/kuroko/hardware-configuration.nix
                (import ./hosts/kuroko/default.nix inputs)
              ];
            };
        };

        mafuyu = functorOSLib.system.instantiate {
          hostname = "mafuyu";
          users = [ kaitotlex ];
          configuration =
            { ... }:
            {
              imports = [
                (import ./config.nix inputs)
                ./hosts/mafuyu/hardware-configuration.nix
                (import ./hosts/mafuyu/default.nix inputs)
              ];
            };
        };

        kanade = functorOSLib.system.instantiate {
          hostname = "kanade";
          users = [ kaitotlex ];
          configuration =
            { ... }:
            {
              imports = [
                (import ./config.nix inputs)
                ./hosts/kanade/hardware-configuration.nix
                (import ./hosts/kanade/default.nix inputs)
              ];
            };
        };
      };

    };
}

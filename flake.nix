{
  description = "KaitoTLex's modification to the already functional functorOS";
  inputs = {
    # Follow the nixpkgs in functorOS, which is verified to build properly before release.
    # github:kaitotlex/functorOS is a stale mirror (agenix wiring reverted there);
    # the canonical repo is the forgejo instance, which has agenix committed.
    functorOS.url = "git+https://code.functor.systems/functor.systems/functorOS.git";
    #functorOS.inputs.apple-firmware.url = "github:binary-star-systems/apple-firmware";
    nixpkgs.follows = "functorOS/nixpkgs";
    corecycler = {
      url = "github:Daaboulex/linux-corecycler";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    functoros-apple-silicon = {
      #url = "github:flokli/nixos-apple-silicon/mainline-mesa";
      url = "github:youwen5/functoros-apple-silicon";
      # url = "github:nix-community/nixos-apple-silicon";
      # inputs.nixpkgs.follows = "nixpkgs";
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

    steam-asahi = {
      url = "git+ssh://git@github.com/KaitoTLex/nixos-asahi-patch";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    polycule-nix = {
      url = "github:KaitoTLex/Polycule-Nix";
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
        shirakami = functorOSLib.system.instantiate {
          hostname = "shirakami-fubuki";
          users = [ kaitotlex ];
          configuration =
            { ... }:
            {
              imports = [
                (import ./config.nix inputs)
                ./hosts/shirakami-fubuki/hardware-configuration.nix
                (import ./hosts/shirakami-fubuki/default.nix inputs)
              ];
            };
        };

        shirakami-fubuki = self.nixosConfigurations.shirakami;

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

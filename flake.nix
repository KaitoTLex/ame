{
  description = "KaitoTLex's modification to the already functional functorOS";
  inputs = {
    # Follow the nixpkgs in functorOS, which is verified to build properly before release.
    # github:kaitotlex/functorOS is a stale mirror (agenix wiring reverted there);
    # the canonical repo is the forgejo instance, which has agenix committed.
    # Pinned one commit before 6e493f4 ("housekeeping"), which dropped
    # nix-index-database but still sets `programs.comma.enable`, an option
    # home-manager doesn't have. Unpin once upstream fixes it.
    functorOS.url = "github:youwen5/functorOS/aa7f6b4e2c81b465125254379afec684f9bdff72";
    #functorOS.url = "git+https://code.functor.systems/kaitotlex/functorOS.git";
    functorOS.inputs.zen-browser.url = "github:KaitoTLex/zen-browser-flake";
    functorOS.inputs.zen-browser.inputs.nixpkgs.follows = "nixpkgs";
    #functorOS.inputs.apple-firmware.url = "github:binary-star-systems/apple-firmware";
    nixpkgs.follows = "functorOS/nixpkgs";
    # nanashi stays on linux 7.1: on 7.2 the xHCI misses isoc service intervals
    # to the IXO22 (crackling). 7.1 is EOL and gone from nixpkgs, so it comes
    # from the last rev nanashi ran it at (7.1.13). Drop once 7.2+ is fixed.
    nixpkgs-linux71.url = "github:nixos/nixpkgs/801bef6abd86b91e51083066b83fb354a11fc640";
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
      # julia_112-bin's test suite segfaults (stress.jl) on newer nixpkgs, so
      # Hydra has no binary and vix1's julia LSP IFD can't build. Pinned to
      # the last rev Hydra built it at. Unpin once upstream fixes it.
      inputs.nixpkgs.url = "github:nixos/nixpkgs/3181085bfd08663b6b9e60bc7a8395c2aaa741bd";
    };
    nix-xilinx = {
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
      inputs.snowfall.follows = "snowfall-lib";
    };

    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    polycule-nix = {
      url = "github:KaitoTLex/Polycule-Nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hermes-agent = {
      url = "github:NousResearch/hermes-agent/v2026.9.14";
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
      # Work account on shirakami-fubuki; home lives on its own NVMe.
      futabatlex = functorOSLib.user.instantiate {
        username = "futabatlex";
        homeDirectory = "/home/futabatlex";
        fullName = "KaitoTLex";
        email = "renl@kaitotlex.systems";
        configureGitUser = true;
        configuration = {
          imports = [
            ./futabatlex.nix
          ];
          functorOS.desktop.niri.enable = true;
          home.stateVersion = "26.05";
        };
      };
    in
    {
      nixosConfigurations = {
        shirakami = functorOSLib.system.instantiate {
          hostname = "shirakami-fubuki";
          users = [
            kaitotlex
            futabatlex
          ];
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

        # ASUS TUF Gaming A14, FA401EA (Ryzen AI MAX+ 392 "Strix Halo", iGPU only).
        # No hardware-configuration.nix: the generated hardware bits, the disk
        # layout and the machine-specific power/input tuning all live in
        # hosts/nanashi/default.nix.
        nanashi = functorOSLib.system.instantiate {
          hostname = "nanashi";
          users = [ kaitotlex ];
          configuration =
            { ... }:
            {
              imports = [
                (import ./config.nix inputs)
                (import ./hosts/nanashi/default.nix inputs)
              ];
            };
        };
      };

    };
}

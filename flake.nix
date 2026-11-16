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

    # scroll: dawsers' sway fork with a scrolling layout, kronii's session
    # (hosts/kronii/scroll.nix). Not in nixpkgs; this flake packages it, rebased
    # on upstream daily, with NixOS and home-manager modules.
    scroll = {
      url = "git+https://codeberg.org/OliMoli/scroll-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # kronii's unpublished services. Their checkouts exist on kronii alone, so
    # these three resolve only there. Other hosts never evaluate them (only
    # hosts/kronii reads them), but `nix flake update` with no argument needs
    # them all and so only works on kronii; elsewhere update inputs by name.
    #
    # airi: Vivado tool layer and the Phase 0 bench harness.
    airi = {
      url = "path:/home/kaitotlex/Source/airi";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # koyori: the print-farm hub ("Takanashi Kiara"), a Rust crate. Only its
    # NixOS module is used, built against this nixpkgs. Read from the checkout's
    # git tree: committed or git-added files only. After a change there,
    # `nix flake update koyori` here to pick it up.
    koyori = {
      url = "git+file:///home/kaitotlex/Source/koyori";
      flake = false;
    };
    # osaka-greeter: the console login screen and status board (greetd). A copy
    # synced from the workstation checkout; `nix flake update osaka-greeter`
    # after syncing.
    osaka-greeter = {
      url = "path:/home/kaitotlex/Source/osaka-greeter";
      flake = false;
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      self,
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

      # Home configurations live in home/<user>; see home/kaitotlex/default.nix.
      kaitotlexIdentity = {
        username = "kaitotlex";
        homeDirectory = "/home/kaitotlex";
        fullName = "KaitoTLex";
        email = "renl@kaitotlex.systems";
        configureGitUser = true;
      };
      kaitotlex = functorOSLib.user.instantiate (
        kaitotlexIdentity
        // {
          configuration = {
            imports = [ ./home/kaitotlex ];
            functorOS.desktop.niri.enable = true;
            # functorOS.desktop.hyprland.screenlocker.useCrashFix = true;
            # functorOS.desktop.waybar.variant = "compact";
            # functorOS.desktop.hyprland.screenlocker.monitor = "eDP-1";
            home.stateVersion = "26.05";
          };
        }
      );
      # Work account on shirakami-fubuki; home lives on its own NVMe.
      futabatlex = functorOSLib.user.instantiate {
        username = "futabatlex";
        homeDirectory = "/home/futabatlex";
        fullName = "KaitoTLex";
        email = "renl@kaitotlex.systems";
        configureGitUser = true;
        configuration = {
          imports = [ ./home/futabatlex ];
          functorOS.desktop.niri.enable = true;
          home.stateVersion = "26.05";
        };
      };

      # Every host is modules/common.nix plus hosts/<hostname>/default.nix,
      # which imports its own hardware-configuration.nix and extra modules.
      mkHost =
        { hostname, users }:
        functorOSLib.system.instantiate {
          inherit hostname users;
          configuration = {
            imports = [
              (import ./modules/common.nix inputs)
              (import ./hosts/${hostname} inputs)
            ];
          };
        };

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems =
        f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      nixosConfigurations = {
        # Mini-ITX desktop, Ryzen 7 7800X3D. Builds and deploys the
        # rest of the fleet with `ame` (pkgs/ame).
        shirakami-fubuki = mkHost {
          hostname = "shirakami-fubuki";
          users = [
            kaitotlex
            futabatlex
          ];
        };
        # Short name, same system.
        shirakami = self.nixosConfigurations.shirakami-fubuki;

        # MacBook Pro M1 Pro on Asahi.
        kanade = mkHost {
          hostname = "kanade";
          users = [ kaitotlex ];
        };

        # ASUS TUF Gaming A14, FA401EA (Ryzen AI MAX+ 392 "Strix Halo", iGPU only).
        # No hardware-configuration.nix: the generated hardware bits, the disk
        # layout and the machine-specific power/input tuning all live in
        # hosts/nanashi/default.nix.
        nanashi = mkHost {
          hostname = "nanashi";
          users = [ kaitotlex ];
        };

        # Threadripper 9970X FPGA build server and print-farm hub, now also a desktop
        # (Arc Pro B60 for the monitors, Tesla V100 for koyori). Builds itself from
        # this checkout with `nh os switch .`; its unpublished services come
        # from the airi, koyori and osaka-greeter inputs above. See
        # hosts/kronii/default.nix.
        kronii = mkHost {
          hostname = "kronii";
          users = [ kaitotlex ];
        };
        # kronii's old name. The running system still reports it until the
        # first switch from here, and nh picks the configuration by hostname.
        osaka = self.nixosConfigurations.kronii;
      };

      # `nix fmt`
      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}

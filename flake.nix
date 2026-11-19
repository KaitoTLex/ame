{
  description = "KaitoTLex's modification to the already functional functorOS";
  inputs = {
    # The canonical functorOS is the forgejo instance (agenix committed,
    # nix-index dropped, overlay build fixes). github:youwen5/functorOS lags it
    # and github:kaitotlex/functorOS is a stale mirror. nixpkgs follows
    # functorOS's lock (a channel tarball), which its overlays are fixed against.
    functorOS.url = "github:youwen5/functorOS/5fd24f5f5c71790f022a340d344e20091dac76ff";
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
    # scroll: sway fork with a scrolling layout. A second session next to niri
    # when functorOS.desktop.scroll.enable is set (modules/scroll.nix).
    scroll-flake = {
      url = "github:Diax170/scroll-flake";
      inputs.nixpkgs.follows = "nixpkgs";
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
    # git tree: tracked files, including uncommitted changes; git-add new files.
    # Deliberately absent from flake.lock while the local checkout is dirty:
    # otherwise rebuilds silently use the old locked revision, losing fixes such
    # as X2D/N6 matching. Nix's "unlocked input" warning is expected. Once the
    # source is committed, `nix flake update koyori` can pin that revision again.
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
      inherit (nixpkgs) lib;
      scrollMod = import ./modules/scroll.nix { inherit inputs; };
      kaitotlex = functorOSLib.user.instantiate {
        username = "kaitotlex";
        homeDirectory = "/home/kaitotlex";
        fullName = "KaitoTLex";
        email = "renl@kaitotlex.systems";
        configureGitUser = true;
        configuration = {
          imports = [
            ./home/kaitotlex.nix
            scrollMod.home
          ];
          # niri everywhere; functorOS.desktop.scroll adds scroll beside it.
          functorOS.desktop.niri.enable = lib.mkDefault true;
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
            ./home/futabatlex.nix
          ];
          functorOS.desktop.niri.enable = true;
          home.stateVersion = "26.05";
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
                (import ./hosts/common.nix inputs)
                ./hosts/shirakami-fubuki/hardware-configuration.nix
                (import ./hosts/shirakami-fubuki/default.nix inputs)
              ];
            };
        };

        shirakami-fubuki = self.nixosConfigurations.shirakami;

        # MacBook Pro M1 Pro on Asahi.
        kanade = functorOSLib.system.instantiate {
          hostname = "kanade";
          users = [ kaitotlex ];
          configuration =
            { ... }:
            {
              imports = [
                (import ./hosts/common.nix inputs)
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
                (import ./hosts/common.nix inputs)
                (import ./hosts/nanashi/default.nix inputs)
              ];
            };
        };

        # ASUS ROG Zephyrus G14 2024, GA403UI (Ryzen 9 8945HS + RTX 4070 Laptop,
        # MUX + Advanced Optimus panel switch).
        blanc = functorOSLib.system.instantiate {
          hostname = "blanc";
          users = [ kaitotlex ];
          configuration =
            { ... }:
            {
              imports = [
                (import ./hosts/common.nix inputs)
                ./hosts/blanc/hardware-configuration.nix
                (import ./hosts/blanc/default.nix inputs)
              ];
            };
        };

        # Threadripper 9970X FPGA build server and print-farm hub, now also a desktop
        # (Arc Pro B60 for the monitors, Tesla V100 for koyori). Builds itself from
        # this checkout with `nh os switch .`; its unpublished services come
        # from the airi, koyori and osaka-greeter inputs above. See
        # hosts/kronii/default.nix.
        kronii = functorOSLib.system.instantiate {
          hostname = "kronii";
          users = [ kaitotlex ];
          configuration =
            { ... }:
            {
              imports = [
                (import ./hosts/common.nix inputs)
                (import ./hosts/kronii/default.nix inputs)
              ];
            };
        };
        # kronii's old name. The running system still reports it until the
        # first switch from here, and nh picks the configuration by hostname.
        osaka = self.nixosConfigurations.kronii;
      };

      # `nix fmt`
      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}

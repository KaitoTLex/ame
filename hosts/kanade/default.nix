inputs:
{ pkgs, lib, ... }:
let
  spotify-asahi = pkgs.mkFexApp {
    pname = "spotify";
    package = pkgs.x86.spotify;
    meta = {
      description = "Spotify (x86_64 via muvm + FEX-Emu)";
    };
  };

  polycule-desktop = pkgs.makeDesktopItem {
    name = "polycule";
    desktopName = "Polycule";
    comment = "Yet another Matrix client";
    exec = "${lib.getExe pkgs.polycule}";
    icon = "${pkgs.polycule}/app/polycule/data/flutter_assets/assets/logo/logo-circle.png";
    categories = [
      "Network"
      "Chat"
      "InstantMessaging"
    ];
  };
in
{
  imports = [
    inputs.functoros-apple-silicon.nixosModules.default
    inputs.steam-asahi.nixosModules.default
    inputs.steam-asahi.nixosModules.xilinx
  ];

  nix.settings = {
    substituters = [ "https://hyprland.cachix.org" ];
    trusted-substituters = [ "https://hyprland.cachix.org" ];
    trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
  };

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = false;
    kernelParams = [ "appledrm.show_notch=1" ];
    kernelModules = [
      "ip_tables"
      "iptable_nat"
      "iptable_filter"
      "iptable_mangle"
    ];
    extraModprobeConfig = ''
      options hid_apple iso_layout=0
    '';
  };

  networking.nftables.enable = true;
  networking.firewall.trustedInterfaces = [ "waydroid0" ];

  services.udev.extraRules = ''
    KERNEL=="macsmc-battery", SUBSYSTEM=="power_supply", ATTR{charge_control_end_threshold}="90", ATTR{charge_control_start_threshold}="85"
  '';

  virtualisation.waydroid.enable = true;

  services = {
    printing.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    tailscale.enable = true;
    logind.settings.Login = {
      HandlePowerKey = "ignore";
    };
    libinput.touchpad = {
      disableWhileTyping = lib.mkForce true;
    };
  };

  nixpkgs.overlays = lib.mkAfter [
    # inputs.apple-silicon.overlays.apple-silicon-overlay
    inputs.tmux.overlay
    inputs.polycule-nix.overlays.default
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

  home-manager.users.kaitotlex.programs.niri.settings.outputs."eDP-1" = {
    mode = {
      width = 3024;
      height = 1964;
      refresh = 120.0;
    };
    scale = 1.333333;
  };

  environment.systemPackages = [
    pkgs.polycule
    polycule-desktop
  ];

  nixpkgs.config.allowUnfree = true;

  programs.steam-asahi.enable = true;

  programs.xilinx = {
    enable = true;
    tools = [ ];
    includeShell = false;
  };

  functorOS = {
    apple-silicon = {
      enable = true;
      peripheralFirmwareDirectory = ./firmware;

      battery.limit = {
        start = 85;
        end = 90;
      };
    };

    theming = {
      wallpaper = "${inputs.wallpapers}/vtubers/sui/nordMachi-retina.png";
      polarity = "dark";
      base16Scheme = ../../scheme/nord.yaml;
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
}

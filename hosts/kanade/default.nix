inputs:
{ pkgs, lib, config, ... }:
let
  spotify-asahi = pkgs.mkFexApp {
    pname = "spotify";
    package = pkgs.x86.spotify;
    meta = {
      description = "Spotify (x86_64 via muvm + FEX-Emu)";
    };
  };

  spotify-desktop = pkgs.makeDesktopItem {
    name = "spotify-asahi";
    desktopName = "Spotify";
    comment = "Spotify (Asahi)";
    exec = "${lib.getExe spotify-asahi} %U";
    icon = "${pkgs.x86.spotify}/share/icons/hicolor/256x256/apps/spotify-client.png";
    categories = [
      "Audio"
      "Music"
      "Player"
    ];
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
    filter-syscalls = false;
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

  # virtualisation.waydroid.enable = true;

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
    spotify-asahi
    spotify-desktop
  ];

  nixpkgs.config.allowUnfree = true;

  programs.steam-asahi.enable = true;

  programs.xilinx = {
    enable = true;
    tools = [ "vivado" ];
    includeShell = true;
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

  age.secrets.eduroam.file = ../../modules/secrets/eduroam.age;

  # SJSU eduroam RADIUS trust anchor (emSign Root CA - G1), extracted from
  # the CAT-generated eduroam-linux-SJSU.py installer. Declared here so the
  # NetworkManager profile below can pin the server cert instead of trusting
  # any AP that answers to the SSID "eduroam". Mirrors hosts/shirakami-fubuki.
  environment.etc."eduroam/ca.pem".text = ''
    -----BEGIN CERTIFICATE-----
    MIIDlDCCAnygAwIBAgIKMfXkYgxsWO3W2DANBgkqhkiG9w0BAQsFADBnMQswCQYD
    VQQGEwJJTjETMBEGA1UECxMKZW1TaWduIFBLSTElMCMGA1UEChMcZU11ZGhyYSBU
    ZWNobm9sb2dpZXMgTGltaXRlZDEcMBoGA1UEAxMTZW1TaWduIFJvb3QgQ0EgLSBH
    MTAeFw0xODAyMTgxODMwMDBaFw00MzAyMTgxODMwMDBaMGcxCzAJBgNVBAYTAklO
    MRMwEQYDVQQLEwplbVNpZ24gUEtJMSUwIwYDVQQKExxlTXVkaHJhIFRlY2hub2xv
    Z2llcyBMaW1pdGVkMRwwGgYDVQQDExNlbVNpZ24gUm9vdCBDQSAtIEcxMIIBIjAN
    BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAk0u76WaK7p1b1TST0Bsew+eeuGQz
    f2N4aLTNLnF115sgxk0pvLZoYIr3IZpWNVrzdr3YzZr/k1ZLpVkGoZM0Kd0WNHVO
    8oG0x5ZOrRkVUkr+PHB1cM2vK6sVmjM8qrOLqs1D/fXqcP/tzxE7lM5OMhbTI0Aq
    d7OvPAEsbO2ZLIvZTmmYsvePQbAyeGHWDV/D+qJAkh1cF+ZwPjXnorfCYuKrpDhM
    tTk1b+oDafo6VGiFbdbyL0NVHpENDtjVaqSW0RM8LHhQ6DqS0hdW5TUaQBw+jSzt
    Od9C4INBdN+jzcKGYEho42kLVACL5HZpIQ15TjQIXhTCzLG3rdd8cIrHhQIDAQAB
    o0IwQDAdBgNVHQ4EFgQU++8Nhp6w492pufEhF38+/PB3KxowDgYDVR0PAQH/BAQD
    AgEGMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBAFn/8oz1h31x
    PaOfG1vR2vjTnGs2vZupYeveFix0PZ7mddrXuqe8QhfnPZHr5X3dPpzxz5KsbEjM
    wiI/aTvFthUvozXGaCocV685743QNcMYDHsAVhzNixl03r4PEuDQqqE/AjSxcM6d
    GNYIAwlG7mDgfrbESQRRfXBgvKqy/3lyeqYdPV8q+Mri/Tm3R7nrft8EI6/6nAYH
    6ftjk4BAtcZsCjEozgyfz7MjNYBBjWzEN3uBL4ChQEKF6dk4jeihU80Bv2noWgby
    RQuQ+q7hv53yrlc8pa6yVvSLZUDp/TGBLPQ5Cdjua6e0ph0VpZj3AYHYhX3zUVxx
    iN66zB+Afko=
    -----END CERTIFICATE-----
  '';

  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ config.age.secrets.eduroam.path ];
    profiles.eduroam = {
      connection = {
        id = "eduroam";
        type = "wifi";
        # Matched by SSID only (no interface-name pin) - robust across
        # kernel/udev interface renames; see hosts/shirakami-fubuki for
        # the failure mode a hardcoded ifname runs into.
      };
      wifi = {
        mode = "infrastructure";
        ssid = "eduroam";
      };
      wifi-security = {
        key-mgmt = "wpa-eap";
      };
      "802-1x" = {
        eap = "peap";
        identity = "ren.lin@sjsu.edu";
        phase2-auth = "mschapv2";
        ca-cert = "/etc/eduroam/ca.pem";
        domain-match = "sjs-0cc-cppm-1.sjsu.edu;sjs-0cc-cppm-2.sjsu.edu;sjs-0mh-cppm-3.sjsu.edu";
        system-ca-certs = false;
        password = "$EDUROAM_PASSWORD";
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
  };
}

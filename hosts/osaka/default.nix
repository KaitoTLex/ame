# osaka: Threadripper 9970X FPGA build server. Headless (an Arc Pro B60 with
# nothing plugged in), formerly ServOS.
#
# This config has everything but airi. airi isn't published yet, so it can't
# be an ame input: every `ame update` would then need a ~/airi checkout.
# ~/osaka on osaka is a small flake that adds airi on top of
# nixosConfigurations.osaka, and is what osaka actually builds from. For the
# same reason osaka isn't in shirakami's `ame` host list.
inputs:
{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ../../modules/server.nix
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  # Installed on 26.05; config.nix's 26.11 is for newer installs.
  system.stateVersion = lib.mkForce "26.05";

  functorOS.flakeLocation = lib.mkForce "/home/kaitotlex/osaka";

  # Only the console and terminal tools get themed here; nanashi's scheme, so
  # ssh sessions from it look the same. The image is required but never shown,
  # so it's a small file from this repo rather than the wallpapers input.
  functorOS.theming = {
    wallpaper = ../../watsonExe.jpeg;
    polarity = "dark";
    base16Scheme = ../../scheme/shigure-ui.yaml;
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "k10temp" ];
    kernelParams = [
      "amd_iommu=on"
      "iommu=pt"
      "amd_pstate=active"
    ];
    extraModprobeConfig = ''
      options kvm_amd nested=1
    '';
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = lib.mkForce false;
    };
    # The keys in /var/lib/sbctl aren't enrolled yet: the firmware is still in
    # setup mode, so this boots signed images without enforcing them.
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      configurationLimit = 20;
    };
  };

  # Synthesis/implementation runs want every core clocked up, and airi-bench
  # results assume it. With amd-pstate active this also pins EPP to
  # performance. power-profiles-daemon would fight the governor.
  powerManagement.cpuFreqGovernor = "performance";
  services.power-profiles-daemon.enable = lib.mkForce false;

  # ECC and PCIe error logging.
  hardware.rasdaemon.enable = true;

  # btrfs subvolumes @, @home, @nix, @log on the "nixos" partition.
  # hardware-configuration.nix mounts them by subvol=; these options add to that.
  fileSystems = {
    "/".options = [
      "compress=zstd"
      "noatime"
    ];
    "/home".options = [
      "compress=zstd"
      "noatime"
    ];
    "/nix".options = [
      "compress=zstd"
      "noatime"
    ];
    "/var/log".options = [
      "compress=zstd"
      "noatime"
    ];
  };
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ]; # one scrub covers every subvolume
  };

  networking.useNetworkd = true;
  networking.useDHCP = false;
  systemd.network = {
    enable = true;
    # Either bond port coming up is enough; an unplugged one never blocks boot.
    wait-online.anyInterface = true;
    # Both onboard ports as one failover link, enp175s0 preferred.
    netdevs."20-bond0" = {
      netdevConfig = {
        Kind = "bond";
        Name = "bond0";
      };
      bondConfig = {
        Mode = "active-backup";
        MIIMonitorSec = "100ms";
        PrimaryReselectPolicy = "always";
      };
    };
    networks = {
      "25-bond0-enp175s0" = {
        matchConfig.Name = "enp175s0";
        linkConfig.RequiredForOnline = "enslaved";
        networkConfig = {
          Bond = "bond0";
          LinkLocalAddressing = "no";
          PrimarySlave = true;
        };
      };
      "25-bond0-enp174s0" = {
        matchConfig.Name = "enp174s0";
        linkConfig.RequiredForOnline = "enslaved";
        networkConfig = {
          Bond = "bond0";
          LinkLocalAddressing = "no";
        };
      };
      # Static .112, so no DHCP-learned DNS can bypass crab-hole.
      "35-bond0" = {
        matchConfig.Name = "bond0";
        linkConfig = {
          # Keep enp175s0's MAC on the bond so UniFi still sees the same client.
          MACAddress = "b0:82:e2:2e:a7:f9";
          RequiredForOnline = "routable";
        };
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = false;
          LinkLocalAddressing = "ipv6";
        };
        address = [ "192.168.1.112/24" ];
        gateway = [ "192.168.1.1" ];
      };
    };
  };

  services.tailscale = {
    enable = true;
    # osaka is a tailnet exit node; "both" turns on IP forwarding.
    useRoutingFeatures = "both";
    extraSetFlags = [
      # crab-hole is the only resolver; MagicDNS must not take over ~.
      "--accept-dns=false"
      "--advertise-exit-node"
    ];
  };
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];
  networking.nftables.enable = true;
  networking.firewall = {
    trustedInterfaces = [ config.services.tailscale.interfaceName ];
    allowedUDPPorts = [ config.services.tailscale.port ];
    # SSH from the wired LAN; tailscale is already trusted. Wifi stays closed.
    interfaces.bond0.allowedTCPPorts = config.services.openssh.ports;
  };

  # crab-hole: local DNS sinkhole blocking adult sites. Listens on loopback
  # only; resolved forwards every query to it.
  services.crab-hole = {
    enable = true;
    settings = {
      blocklist = {
        include_subdomains = true;
        lists = [
          "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts"
          "https://blocklistproject.github.io/Lists/porn.txt"
        ];
      };
      downstream = [
        {
          protocol = "udp";
          listen = "127.0.0.1";
          port = 53;
        }
      ];
      # Cloudflare for Families (malware + adult) over DoT, as a second layer.
      upstream.name_servers = [
        {
          socket_addr = "1.1.1.3:853";
          protocol = "tls";
          tls_dns_name = "family.cloudflare-dns.com";
          trust_nx_responses = false;
        }
        {
          socket_addr = "1.0.0.3:853";
          protocol = "tls";
          tls_dns_name = "family.cloudflare-dns.com";
          trust_nx_responses = false;
        }
      ];
    };
  };
  # Send all lookups to crab-hole: no DHCP-learned or fallback resolvers.
  services.resolved.settings.Resolve = {
    DNS = [ "127.0.0.1" ];
    Domains = [ "~." ];
    FallbackDNS = [ ];
  };

  users.users.kaitotlex.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMkS6tVvx8qfgfWaP3W2MjWl8lYvu9NK75db9Fyn3oSR kaitotlex@nanashi"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHjmMf4qjTI2ltl6FVRAjbnIiOguyXfRQnTcNhde2coZ kaitotlex@chisa"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMwfHIQZRf1T89mkTnsCO24+q7B027UoolG1hgEYdQi4 lrcocobao@icloud.com"
  ];
  # run0 can't prompt over a non-interactive ssh session, so remote admin and
  # `nixos-rebuild --target-host` log in as root, with nanashi's key only and
  # only from the tailnet or the LAN (like deploy-target.nix, plus the LAN as
  # a way back in if tailscale is down). kaitotlex's password lives in
  # /etc/shadow (users are mutable); set it with `passwd`, run0 asks for it.
  users.users.root.openssh.authorizedKeys.keys = [
    ''from="100.64.0.0/10,192.168.1.0/24" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMkS6tVvx8qfgfWaP3W2MjWl8lYvu9NK75db9Fyn3oSR kaitotlex@nanashi''
  ];

  environment.systemPackages = with pkgs; [
    sbctl
    numactl
    hwloc
    lm_sensors
    dmidecode
    edac-utils
    config.boot.kernelPackages.cpupower
    # FPGA/HDL work; Vivado itself comes from airi.
    verilator
    gnumake
    cmake
    claude-code
  ];
}

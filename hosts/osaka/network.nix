# Wired LAN (both onboard ports bonded, static .112), tailscale as an exit
# node, and the firewall. DNS is dns.nix.
{ config, ... }:
{
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
}

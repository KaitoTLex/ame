# Tailscale (through an exit node), nftables firewall, sshd from the wired LAN
# and the tailnet only, and eduroam over NetworkManager.
{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [ ../../modules/eduroam ];

  # Pin the profile to the AP this machine actually sits next to.
  networking.networkmanager.ensureProfiles.profiles.eduroam.wifi.bssid = "1C:30:03:9C:4A:61";

  services.tailscale = {
    enable = true;
    # This host routes through an exit node; "client" loosens reverse-path
    # filtering so exit-node traffic isn't dropped.
    useRoutingFeatures = "client";
    # Keep the wired LAN reachable while an exit node is active, otherwise
    # replies to LAN SSH get routed out through the exit node.
    extraSetFlags = [ "--exit-node-allow-lan-access=true" ];
  };
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ config.services.tailscale.interfaceName ];
    allowedUDPPorts = [ config.services.tailscale.port ];
    # Allow SSH from the wired LAN only; wifi stays closed. Tailscale is
    # already reachable via trustedInterfaces.
    interfaces.enp12s0.allowedTCPPorts = config.services.openssh.ports;
  };
  services.openssh = {
    enable = true;
    # Don't open port 22 globally; the per-interface rule above handles it.
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [
        "kaitotlex"
        "futabatlex"
      ];
    };
  };
  users.users.kaitotlex.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMkS6tVvx8qfgfWaP3W2MjWl8lYvu9NK75db9Fyn3oSR kaitotlex@nanashi"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHjmMf4qjTI2ltl6FVRAjbnIiOguyXfRQnTcNhde2coZ kaitotlex@chisa"
  ];
  users.users.futabatlex.openssh.authorizedKeys.keys =
    config.users.users.kaitotlex.openssh.authorizedKeys.keys;
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];
  systemd.network.wait-online.enable = false;
  boot.initrd.systemd.network.wait-online.enable = false;
}

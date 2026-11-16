{
  pkgs,
  lib,
  config,
  ...
}:
# UniFi Endpoint desktop client.
#
# Upstream only ships for FHS distros, so this module stands in for the .deb's
# postinst and recreates the absolute paths its binaries hard-code:
#
#   1. The daemon starts the root helper with
#      `pkexec /usr/lib/UniFi-Endpoint/UniFi-Endpoint-PrivilegedHelper`, and the
#      polkit policy authorizes that exact path. The path is compiled in, so it
#      has to exist: we symlink it to the store.
#
#   2. The helper resets PATH to /usr/sbin:/usr/bin:/sbin:/bin and also probes
#      /usr/bin/<tool> directly, so the tools it runs are symlinked in /usr/bin.
#
# Not supported: SSL inspection. Installing the workspace CA needs
# update-ca-certificates or update-ca-trust, and NixOS has neither. It is gated
# on the unifi-endpoint group, which nobody is added to here.
let
  cfg = config.ame.unifi-endpoint;
  package = pkgs.callPackage ../../pkgs/unifi-endpoint { };

  helperTools = {
    getent = "${lib.getBin pkgs.glibc}/bin/getent";
    id = "${pkgs.coreutils}/bin/id";
    ip = "${pkgs.iproute2}/bin/ip";
    nmcli = "${config.networking.networkmanager.package}/bin/nmcli";
    pkexec = "/run/wrappers/bin/pkexec";
    resolvconf = "${pkgs.openresolv}/bin/resolvconf";
    wg-quick = "${pkgs.wireguard-tools}/bin/wg-quick";
  };
in
{
  options.ame.unifi-endpoint.enable = lib.mkEnableOption "the UniFi Endpoint desktop client";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      package
      pkgs.libnotify
      pkgs.libsecret
      pkgs.xdg-utils
    ];

    systemd.tmpfiles.rules = [
      "L+ /usr/lib/UniFi-Endpoint - - - - ${package}/lib/UniFi-Endpoint"
    ]
    ++ lib.mapAttrsToList (name: target: "L+ /usr/bin/${name} - - - - ${target}") helperTools;

    # Socket-activated per-user daemon; the unit has no [Install] of its own.
    systemd.packages = [ package ];
    systemd.user.sockets.UniFi-Endpoint-Daemon.wantedBy = [ "sockets.target" ];

    environment.etc."polkit-1/rules.d/50-unifi-endpoint.rules".source =
      "${package}/share/unifi-endpoint/50-unifi-endpoint.rules";

    environment.etc."NetworkManager/conf.d/90-unifi-endpoint-unmanaged-vpn.conf".source =
      "${package}/share/unifi-endpoint/90-unifi-endpoint-unmanaged-vpn.conf";

    users.groups.unifi-endpoint = { };
  };
}

# eduroam over NetworkManager (shirakami-fubuki, nanashi). kanade runs iwd
# without NetworkManager and uses ./iwd.nix instead.
{ config, ... }:
{
  imports = [ ./common.nix ];

  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ config.age.secrets.eduroam.path ];
    profiles.eduroam = {
      connection = {
        id = "eduroam";
        type = "wifi";
      };
      wifi = {
        mode = "infrastructure";
        ssid = "eduroam";
      };
      wifi-security.key-mgmt = "wpa-eap";
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

# eduroam over iwd, without NetworkManager (kanade). The profile is written
# into /var/lib/iwd from the agenix secret by a oneshot at boot.
{ config, lib, ... }:
{
  imports = [ ./common.nix ];

  # functorOS otherwise leaves NetworkManager enabled with iwd as its Wi-Fi
  # backend. Disable the frontend so iwctl talks directly to iwd.
  networking.networkmanager.enable = lib.mkForce false;

  # This service is deliberately not required by iwd. A malformed or missing
  # credential must not prevent the wireless daemon from starting.
  systemd.services.iwd-eduroam-profile = {
    description = "Provision the native iwd eduroam profile";
    wantedBy = [ "multi-user.target" ];
    after = [ "iwd.service" ];
    restartTriggers = [ config.age.secrets.eduroam.file ];
    serviceConfig = {
      Type = "oneshot";
      LoadCredential = "eduroam-password:${config.age.secrets.eduroam.path}";
    };
    script = ''
      set -eu
      umask 077

      credential=$(<"$CREDENTIALS_DIRECTORY/eduroam-password")
      password=''${credential#EDUROAM_PASSWORD=}
      if [[ -z $password ]]; then
        echo "The eduroam password credential is empty" >&2
        exit 1
      fi

      # Escape characters with special meaning in an iwd settings value.
      password=''${password//\\/\\\\}
      password=''${password//$'\t'/\\t}
      password=''${password//$'\r'/\\r}
      password=''${password//$'\n'/\\n}
      if [[ $password == " "* ]]; then
        password="\\s''${password:1}"
      fi

      install -d -m 0700 /var/lib/iwd
      profile=$(mktemp /var/lib/iwd/.eduroam.8021x.XXXXXX)
      trap 'rm -f "$profile"' EXIT

      printf '%s\n' \
        '[Security]' \
        'EAP-Method=PEAP' \
        'EAP-Identity=ren.lin@sjsu.edu' \
        'EAP-PEAP-CACert=/etc/eduroam/ca.pem' \
        'EAP-PEAP-ServerDomainMask=sjs-0cc-cppm-1.sjsu.edu;sjs-0cc-cppm-2.sjsu.edu;sjs-0mh-cppm-3.sjsu.edu' \
        'EAP-PEAP-Phase2-Method=MSCHAPV2' \
        'EAP-PEAP-Phase2-Identity=ren.lin@sjsu.edu' \
        "EAP-PEAP-Phase2-Password=$password" \
        '[Settings]' \
        'AutoConnect=true' > "$profile"

      mv -f "$profile" /var/lib/iwd/eduroam.8021x
      trap - EXIT
    '';
  };
}

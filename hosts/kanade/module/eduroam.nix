{ config, lib, ... }:
{
  # functorOS otherwise leaves NetworkManager enabled with iwd as its Wi-Fi
  # backend. Disable the frontend so iwctl talks directly to iwd.
  networking.networkmanager.enable = lib.mkForce false;

  age.secrets.eduroam.file = ../secrets/eduroam.age;

  # SJSU eduroam RADIUS trust anchor (emSign Root CA - G1), extracted from
  # the CAT-generated eduroam-linux-SJSU.py installer.
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

      password=$(<"$CREDENTIALS_DIRECTORY/eduroam-password")
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

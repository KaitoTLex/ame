# Bifrost (maximhq), an AI gateway in front of llm-router, on :8088:
#
#   clients -> bifrost :8088 -> llm-router :8080 -> Arc :8081
#
# Bifrost adds what the router doesn't do: a web UI, request logs, virtual
# keys with budgets and rate limits, and fallbacks to cloud providers if any
# get added. Models are addressed as kronii/<model>, e.g.
# kronii/huihui-qwen3.8-27b-abliterated.
#
# Like the router, it binds everywhere and the firewall only lets the tailnet
# and loopback in: http://kronii:8088/.
#
# config.json below only seeds the provider. Bifrost keeps its real config in
# /var/lib/bifrost/config.db, so UI edits survive restarts; changing the
# provider here overwrites that provider's row at the next start. The first
# admin account needs the setup token, generated on first start:
#   sudo cat /var/lib/bifrost/setup-token
{ pkgs, ... }:
let
  port = 8088;
  stateDir = "/var/lib/bifrost";
  # The upstream build, not built from source: the binary embeds the Next.js
  # UI, which would need its own npm build. It is static, so it runs as is.
  # v2.3.2 has no published checksum (those start at v2.3.3); the hash is of
  # the binary as downloaded on 2026-10-29.
  bifrost = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "bifrost";
    version = "2.3.2";
    src = pkgs.fetchurl {
      url = "https://downloads.getmaxim.ai/bifrost/v${version}/linux/amd64/bifrost-http";
      hash = "sha256-KboEVv2tHk7qrew2ymA03Wp3wzWIKq2RpeIP/yZnPRU=";
    };
    dontUnpack = true;
    dontFixup = true;
    installPhase = "install -Dm755 $src $out/bin/bifrost-http";
    meta.mainProgram = "bifrost-http";
  };
  config = pkgs.writeText "bifrost-config.json" (
    builtins.toJSON {
      "$schema" = "https://www.getbifrost.ai/schema";
      providers.kronii = {
        # Keyless, but Bifrost still routes through a key entry, and a key's
        # model list is deny-by-default.
        keys = [
          {
            name = "kronii";
            value = "";
            models = [ "*" ];
            weight = 1.0;
          }
        ];
        custom_provider_config = {
          base_provider_type = "openai";
          is_key_less = true;
        };
        network_config = {
          base_url = "http://127.0.0.1:8080";
          # The Arc runs one slot, so a request can queue behind another
          # before a long prefill; the defaults would cut that off.
          default_request_timeout_in_seconds = 1800;
          stream_idle_timeout_in_seconds = 900;
          max_retries = 0;
        };
      };
      config_store = {
        enabled = true;
        type = "sqlite";
        config.path = "${stateDir}/config.db";
      };
      logs_store = {
        enabled = true;
        type = "sqlite";
        config.path = "${stateDir}/logs.db";
      };
    }
  );
in
{
  systemd.services.bifrost = {
    description = "Bifrost AI gateway in front of llm-router";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network.target"
      "llm-router.service"
    ];
    path = [ pkgs.coreutils ];
    environment.HOME = stateDir;
    script = ''
      install -m 0644 ${config} ${stateDir}/config.json
      if [ ! -s ${stateDir}/setup-token ]; then
        head -c 32 /dev/urandom | base64 | tr -d '/+=' > ${stateDir}/setup-token
      fi
      BIFROST_SETUP_TOKEN=$(cat ${stateDir}/setup-token)
      export BIFROST_SETUP_TOKEN
      exec ${bifrost}/bin/bifrost-http -host 0.0.0.0 -port ${toString port} -app-dir ${stateDir}
    '';
    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "bifrost";
      WorkingDirectory = stateDir;
      UMask = "0077";
      Restart = "always";
      RestartSec = 2;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
    };
  };

  environment.systemPackages = [ bifrost ];
}

# Local LLM on the Arc Pro B60, behind an OpenAI-compatible endpoint on :8080:
#
#   Arc Pro B60 (24 GB)  Huihui Qwen3.8-27B abliterated, llama.cpp Vulkan,
#                        127.0.0.1:8081
#   llm-router           :8080, a thin proxy in front of it (llm-router.py). It
#                        can also route a second backend by model name and
#                        overflow short requests to it (BONSAI_URL); none is
#                        configured now.
#
# The router binds everywhere, but the firewall only lets the tailnet and
# loopback in. The server only sees the Arc.
#
# The Tesla V100 used to run puno's bonsaid (Ternary Bonsai 2 27B) from a build in
# ~/Source/puno. That service was removed on 2026-11-13: its binary lived outside the
# Nix store, so nixos-rebuild switch could not rebuild or restart it, and it had been
# restart-looping (exit 127) since the build went away. Bring it back as a packaged
# derivation, not a path into a home directory. /var/lib/bonsaid can be deleted.
{ pkgs, ... }:
let
  router = pkgs.writers.writePython3Bin "llm-router" {
    libraries = [ pkgs.python3Packages.aiohttp ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./llm-router.py);
  # huihui-ai's abliterated Qwen3.8-27B, in huihui-ai's own GGUF quant.
  # (turboderp's EXL3 quant of it needs ExLlamaV3, which is CUDA-only, so it
  # can't run on the Arc.) The GGUF keeps the base model's multi-token-
  # prediction head (blk.64.nextn.*), which llama.cpp drafts with
  # (--spec-type draft-mtp); drop spec-type to run it as a plain model.
  model = {
    repo = "huihui-ai/Huihui-Qwen3.8-27B-abliterated-GGUF";
    rev = "1c69098e9c32db6dc06fc48f1d6cc75ad07da89e";
    file = "Huihui-Qwen3.8-27B-abliterated-Q4_K.gguf";
    sha256 = "6c2c13cef89238c3604d756b07b3ef5fafebbd61095feb8553ff449c95e4c1c6";
  };
  # 17 GB has no business in the store; it's fetched once and kept here.
  modelPath = "/var/lib/llama-models/${baseNameOf model.repo}/${model.file}";
in
{
  systemd.services.llama-model = {
    description = "Download ${model.repo}/${model.file}";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "!${modelPath}";
    path = [
      pkgs.curl
      pkgs.coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      RestartSec = 60;
    };
    script = ''
      dir=$(dirname ${modelPath})
      mkdir -p "$dir"
      chmod 755 /var/lib/llama-models "$dir"
      part=${modelPath}.part
      curl -fL --retry 10 --retry-all-errors -C - -o "$part" \
        https://huggingface.co/${model.repo}/resolve/${model.rev}/${model.file}
      echo "${model.sha256}  $part" | sha256sum -c
      chmod 644 "$part"
      mv "$part" ${modelPath}
    '';
  };

  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp-vulkan;
    settings = {
      # Behind llm-router; only it talks to this port.
      host = "127.0.0.1";
      port = 8081;
      model = modelPath;
      alias = "huihui-qwen3.8-27b-abliterated";
      n-gpu-layers = "all";
      ctx-size = 65536;
      flash-attn = "on";
      cache-type-k = "q8_0";
      cache-type-v = "q8_0";
      # MTP drafting needs a single slot.
      parallel = 1;
      spec-type = "draft-mtp";
      spec-draft-n-max = 2;
      # Qwen's defaults for thinking mode; requests can override them.
      temp = 1.0;
      top-p = 0.95;
      top-k = 20;
      min-p = 0.0;
    };
  };

  systemd.services.llama-cpp = {
    wants = [ "llama-model.service" ];
    after = [ "llama-model.service" ];
    # Only the B60: hide the V100's (nvidia) and Mesa's CPU Vulkan drivers.
    environment = {
      VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
      # The DynamicUser's HOME is read-only; without this Mesa recompiles
      # every shader on each start.
      MESA_SHADER_CACHE_DIR = "/var/cache/llama-cpp/mesa";
    };
  };

  systemd.services.llm-router = {
    description = "OpenAI-compatible router in front of the Arc LLM server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment = {
      LISTEN = "0.0.0.0:8080";
      ARC_URL = "http://127.0.0.1:8081";
    };
    serviceConfig = {
      ExecStart = "${router}/bin/llm-router";
      DynamicUser = true;
      Restart = "always";
      RestartSec = 2;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
    };
  };

  environment.systemPackages = [ pkgs.llama-cpp-vulkan ];
}

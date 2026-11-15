# Local LLM: llama.cpp (PrismML fork) on the NVIDIA card, started on demand
# behind llama-gate.py, and the gamemode hooks that evict it for games.
{
  pkgs,
  lib,
  config,
  ...
}:
{
  # The local Qwen model is slightly larger than VRAM. Compressed swap keeps a
  # long-context request from turning transient memory pressure into an OOM.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  environment.systemPackages = [ config.services.llama-cpp.package ];

  # llama-server pulls the GGUF from Hugging Face into /var/cache/llama-cpp on
  # first start.
  services.llama-cpp = {
    enable = true;
    # PrismML fork, not nixpkgs' llama-cpp: PQ2_0 is a Prism-private quant
    # format (ggml.h: GGML_TYPE_PQ2_0 = 142) that mainline rejects at load.
    # The fork is a superset of mainline, so ordinary quants still work --
    # which is what the Q3_K_M below relies on. Verified the fork's libllama
    # knows this model's architecture: its arch table contains `qwen35`
    # (alongside qwen35moe/qwen3next/qwen3vl), so no repackaging is needed.
    package = pkgs.callPackage ../../pkgs/llama-cpp-prism { };
    settings = {
      # Qwen3.5-27B SFT'd on Claude-4.6-Opus chain-of-thought traces.
      # hf-file is pinned explicitly rather than using a `:QUANT` tag on
      # hf-repo, so the resolved file cannot drift when the repo is retagged.
      hf-repo = "Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-GGUF";
      hf-file = "Qwen3.5-27B.Q3_K_M.gguf";
      alias = "qwen3.5-27b-opus-distilled";
      # Hermes Agent refuses any model reporting under 64K context, so 65536
      # is a hard floor, not a preference. It fits because this is a hybrid
      # model: only 16 of its 64 layers are full_attention and hold a growing
      # KV cache -- the other 48 are linear_attention with a fixed-size state.
      # So KV at 64K is 16 layers * 4 kv-heads * 256 head_dim * 2 * 65536 at
      # q8_0 ~= 2.0 GiB, against 0.75 GiB at 24576. Measured 13964 MiB total
      # at ctx 24576, giving ~13196 MiB of weights, so 64K projects to
      # ~15244 MiB of this card's 16303 MiB. ~1 GiB headroom: it fits, but do
      # not raise this further without re-measuring. The model itself declares
      # max_position_embeddings = 262144.
      ctx-size = 65536;
      cache-type-k = "q8_0";
      cache-type-v = "q8_0";
      flash-attn = "on";
      # -ngl defaults to "auto", and auto parked layer 0 on CPU, which killed
      # the fused kernels for the whole model:
      #   resolve_fused_ops: layer 0 is assigned to device CPU but fused
      #     Gated Delta Net (autoregressive) is assigned to device CUDA0
      #   resolve_fused_ops: fused Gated Delta Net (chunked) ... set to disabled
      # Gated Delta Net is the kernel for the linear_attention layers -- 48 of
      # this model's 64 -- so one CPU-resident layer disabled the fast path for
      # three quarters of the network. "all" forces every layer onto CUDA0.
      n-gpu-layers = "all";
      # Thinking stays on (it is what the Opus distillation bought) but capped:
      # unbudgeted, "what is 17 times 23" spent 742 generated tokens inside the
      # reasoning block. 2048 leaves room for a real chain of thought on a
      # morning brief without paying it on trivia. -1 = unrestricted, 0 = off.
      reasoning-budget = 2048;
      # Required: this fine-tune exists partly to fix the upstream Jinja
      # template crashing on the "developer" role that coding agents send.
      jinja = true;
      # The repo ships mmproj-F32.gguf (0.93 GB). Deliberately not loaded --
      # that GiB is better spent on KV cache, and the Hermes provider below
      # declares supports_vision = false to match.
      no-mmproj = true;
      # No chat-template-kwargs here. That was mandatory for Ternary Bonsai
      # (its card measured StrongReject 0.513 vs 0.977); this model card says
      # thinking mode is on by default and specifies no required kwargs.
      # Internal; clients use the socket-activated proxy below.
      port = 8081;
    };
  };

  # Run llama-server on demand rather than always holding the GPU. Clients talk
  # to llama-gate on 127.0.0.1:8080, which answers metadata probes itself and
  # only forwards inference to 127.0.0.1:8082; the first connection there
  # starts the proxy, which pulls up llama-cpp. After 10 idle minutes the
  # proxy exits and llama-cpp stops with it.
  systemd.services.llama-cpp = {
    wantedBy = lib.mkForce [ ];
    unitConfig.StopWhenUnneeded = true;
    # Don't let a deploy reload the model. switch-to-configuration restarts
    # any changed unit that was running, which brought llama-cpp straight
    # back up (and OOM'd, the old process still holding VRAM). Now a running
    # instance is left alone until the proxy goes idle or gets restarted,
    # StopWhenUnneeded takes it down then, and the next request starts the
    # new version.
    restartIfChanged = false;
    serviceConfig = {
      # Only count as started once the model is loaded, so the proxy never
      # forwards to a port nobody is listening on. The first download of a
      # quant is ~13 GB, hence no start timeout. Give up as soon as
      # llama-server itself is gone though (say, a CUDA OOM at load):
      # otherwise the start job hangs forever, and so does any nixos
      # activation waiting on it, holding the switch-to-configuration lock.
      #
      # $MAINPID must be passed as an ARGUMENT, not referenced inside the
      # script. systemd expands specifiers like $MAINPID only in the
      # Exec*= line itself; inside the script body it is an ordinary shell
      # variable that is simply unset, so `[[ -e /proc/$MAINPID ]]` tested
      # `/proc/`, which always exists -- no, worse: it made the guard fire on
      # the first iteration and the unit died in 44ms with
      # "Control process exited, code=exited, status=1/FAILURE", looping until
      # start-limit-hit. Verified with a throwaway unit: systemd logs
      # "Referenced but unset environment variable evaluates to an empty
      # string: MAINPID" for the in-script form.
      ExecStartPost = [
        "${pkgs.writeShellScript "llama-cpp-wait-ready" ''
          main_pid="$1"
          until ${lib.getExe pkgs.curl} --silent --fail --output /dev/null \
            http://127.0.0.1:${toString config.services.llama-cpp.settings.port}/health; do
            if [ -z "$main_pid" ] || [ ! -e "/proc/$main_pid" ]; then
              echo "llama-server (pid $main_pid) is gone before /health came up" >&2
              exit 1
            fi
            sleep 2
          done
        ''} $MAINPID"
      ];
      TimeoutStartSec = "infinity";
      # NOTE: do NOT bind-mount the cache onto /data to save root space. The
      # upstream module runs this with DynamicUser=yes + PrivateUsers=yes, so
      # the UID is allocated at runtime from 61184-65519 -- there is no UID to
      # chown a /data directory to in advance, and PrivateUsers keeps
      # SupplementaryGroups from mapping. systemd handles it correctly on its
      # own via CacheDirectory (the real path is /var/cache/private/llama-cpp,
      # 0700 and dynamically owned). Tried and reverted: a
      # BindPaths=/data/llama-cpp:/var/cache/llama-cpp made llama-server die at
      # startup with "cannot create directories: Permission denied". Relocating
      # this needs a static system user first.
    };
  };
  systemd.sockets.llama-cpp-proxy = {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:8082" ];
  };
  systemd.services.llama-cpp-proxy = {
    requires = [ "llama-cpp.service" ];
    after = [ "llama-cpp.service" ];
    serviceConfig = {
      ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd --exit-idle-time=10min 127.0.0.1:${toString config.services.llama-cpp.settings.port}";
      DynamicUser = true;
    };
  };
  # Every Hermes gateway probes /v1/props, /v1/models etc. at startup; through
  # a plain TCP proxy that alone loaded the model at login. The gate answers
  # those from config so only an actual completion request wakes llama-cpp.
  systemd.services.llama-gate = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = lib.escapeShellArgs [
        (lib.getExe pkgs.python3)
        ./llama-gate.py
        "8080"
        "8082"
        config.services.llama-cpp.settings.alias
        (toString config.services.llama-cpp.settings.ctx-size)
      ];
      DynamicUser = true;
      Restart = "always";
    };
  };

  # llama-server holds ~14 GiB of the 16 GiB card, and the Hermes gateways wake
  # it at login, so games launched afterwards hit NVRM "Out of memory" (Death
  # Stranding 2 hung on start). Games run via `gamemoderun %command%` free the
  # card: the socket is stopped too so Hermes can't re-wake the model mid-game,
  # and re-armed when the game exits (the model reloads on next request).
  # functorOS already enables gamemode with notify-send hooks; these keep the
  # notifications and add the llama-cpp part.
  programs.gamemode.settings.custom = {
    start = lib.mkForce (
      toString (
        pkgs.writeShellScript "gamemode-start" ''
          ${config.systemd.package}/bin/systemctl stop llama-cpp-proxy.socket llama-cpp-proxy.service llama-cpp.service
          ${pkgs.libnotify}/bin/notify-send 'GameMode engaged'
        ''
      )
    );
    end = lib.mkForce (
      toString (
        pkgs.writeShellScript "gamemode-end" ''
          ${config.systemd.package}/bin/systemctl start llama-cpp-proxy.socket
          ${pkgs.libnotify}/bin/notify-send 'GameMode disengaged'
        ''
      )
    );
  };
  # gamemoded runs the hooks as the user; let it toggle just these units.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.user == "kaitotlex" &&
          ["llama-cpp.service", "llama-cpp-proxy.service", "llama-cpp-proxy.socket"]
            .indexOf(action.lookup("unit")) >= 0 &&
          ["start", "stop"].indexOf(action.lookup("verb")) >= 0) {
        return polkit.Result.YES;
      }
    });
  '';
}

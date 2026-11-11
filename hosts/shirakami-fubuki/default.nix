inputs:
{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ../../modules/eduroam.nix
    ./drives.nix
    ./sittimchest.nix
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.corecycler.nixosModules.default
  ];

  boot = {
    # The IXO22's asynchronous USB feedback can lock far below its 48 kHz rate.
    extraModprobeConfig = ''
      options snd_usb_audio lowlatency=0
    '';
    loader = {
      efi.canTouchEfiVariables = true;
      timeout = 15;
      systemd-boot.enable = lib.mkForce false;
    };
    kernelPackages = pkgs.linuxPackages_7_3;
    kernelModules = [ "uinput" ];
    kernelParams = [ "amd_pstate=active" ];
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };

  # services.supergfxd.enable = true;
  hardware.opentabletdriver.enable = true;
  hardware.uinput.enable = true;
  services.corecycler = {
    enable = true;
    deviceAccessUser = "kaitotlex"; # required -- grants MSR/SMU access without sudo
    unfreeBackends = true; # include mprime (best for CO tuning)
    # Ryzen 7 7800X3D (Zen 4, single CCD, 8 cores/16 threads, V-Cache) on an
    # ASUS/MSI/ASRock board -- Nuvoton Super I/O, not ITE.
    zenpower = true; # zenpower5: SVI2 voltage + RAPL power, richer than k10temp
    nct6775 = true; # Nuvoton Super I/O -- Vcore/fan/temp (most ASUS/MSI/ASRock boards)
    nct6683 = true; # newer Nuvoton chip variant on some MSI boards; no-op if not present
    spd5118 = true; # AM5 is DDR5-only -- DIMM temps via the SPD hub
  };
  # scroll next to niri. Same DMS, same keymap, zero gaps. modules/scroll.nix.
  functorOS.desktop.scroll.enable = true;
  ame.unifi-endpoint.enable = true;

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
  users.users.futabatlex = {
    shell = lib.mkForce pkgs.zsh;
    openssh.authorizedKeys.keys = config.users.users.kaitotlex.openssh.authorizedKeys.keys;
  };
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];
  systemd.network.wait-online.enable = false;
  boot.initrd.systemd.network.wait-online.enable = false;
  security.rtkit.enable = true;

  # The local Qwen model is slightly larger than VRAM. Compressed swap keeps a
  # long-context request from turning transient memory pressure into an OOM.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  services.lact.enable = true;
  hardware.amdgpu.overdrive.enable = true;
  # ROCm for the Ryzen iGPU (Radeon 610M).
  hardware.amdgpu.opencl.enable = true;

  environment.systemPackages = with pkgs; [
    ryzenadj
    linuxPackages_zen.cpupower
    stress-ng
    rocmPackages.rocm-smi
    rocmPackages.rocminfo

    config.services.llama-cpp.package

    # Fleet deploys, see boot.binfmt.emulatedSystems further down.
    (callPackage ../../pkgs/ame {
      flake = config.functorOS.flakeLocation;
      hosts = [
        "shirakami-fubuki"
        "nanashi"
        "kanade"
      ];
    })
  ];
  nixpkgs.config.allowUnfree = true;

  # functorOS.system.graphics.nvidia.enable (set below) already configures
  # modesetting/powerManagement/nvidiaSettings/open/the driver package and
  # hardware.graphics.enable, so only PRIME bus wiring needs to happen here.
  #
  # functorOS declares nvidia.optimus-prime.enable/powerMode but does not
  # wire them to anything yet (checked modules/linux/graphics/default.nix,
  # rev 61d2323), so PRIME is still configured via hardware.nvidia.prime
  # directly. `sync`/`reverseSync` only work under Xorg and are a silent
  # no-op under niri (pure Wayland, no X server driving the session) -
  # `offload` is the mode that actually works with Wayland compositors.
  hardware.nvidia.prime = {
    nvidiaBusId = "PCI:1:0:0";
    amdgpuBusId = "PCI:16:0:0";
    offload = {
      enable = true;
      enableOffloadCmd = true;
    };
  };

  # niri + NVIDIA is known to leak VRAM into a free buffer pool
  # (https://github.com/niri-wm/niri/wiki/Nvidia); cap the reuse ratio.
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
    builtins.toJSON {
      rules = [
        {
          pattern = {
            feature = "procname";
            matches = "niri";
          };
          profile = "Limit Free Buffer Pool On Wayland Compositors";
        }
      ];
      profiles = [
        {
          name = "Limit Free Buffer Pool On Wayland Compositors";
          settings = [
            {
              key = "GLVidHeapReuseRatio";
              value = 0;
            }
          ];
        }
      ];
    };

  # environment.systemPackages = [ pkgs.supergfxctl ];

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main = {
          capslock = "esc";
          leftalt = "leftcontrol";
          leftcontrol = "leftalt";
          y = "z";
          z = "y";
          esc = "`";
        };
      };
    };
  };

  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
  };
  programs.xwayland.enable = true;

  nixpkgs.overlays = lib.mkAfter [
    (import ../../modules/xilinx-overlay.nix inputs)
  ];
  programs.steam.enable = true;
  functorOS = {
    theming = {
      wallpaper = "${inputs.wallpapers}/math/watsonbif.png";
      polarity = "light";
      base16Scheme = ../../scheme/watson.yaml;
    };
    system = {
      networking = {
        firewallPresets.vite = false;
      };
      graphics.nvidia.enable = true;
    };
    extras.gaming = {
      enable = true;
    };
  };
  age.secrets.eduroam.file = ../../modules/secrets/eduroam.age;

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
        bssid = "1C:30:03:9C:4A:61";
      };
      wifi-security = {
        key-mgmt = "wpa-eap";
      };
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
    package = pkgs.callPackage ../../pkgs/llama-cpp-prism.nix { };
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
        ''${pkgs.writeShellScript "llama-cpp-wait-ready" ''
          main_pid="$1"
          until ${lib.getExe pkgs.curl} --silent --fail --output /dev/null \
            http://127.0.0.1:${toString config.services.llama-cpp.settings.port}/health; do
            if [ -z "$main_pid" ] || [ ! -e "/proc/$main_pid" ]; then
              echo "llama-server (pid $main_pid) is gone before /health came up" >&2
              exit 1
            fi
            sleep 2
          done
        ''} $MAINPID''
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

  users.users.kaitotlex.linger = true;

  # shirakami builds and deploys the whole fleet: `ame switch` builds every
  # host here and pushes it out over tailscale (pkgs/ame, and
  # modules/deploy-target.nix on the receiving end). kanade is aarch64, so
  # build it under qemu; most of it still comes from the binary cache.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  # Scanned over tailscale, which already authenticates the peer. kanade isn't
  # pinned because it was offline at the time; ame trusts it on first contact.
  programs.ssh.knownHosts.nanashi = {
    hostNames = [
      "nanashi"
      "nanashi.tail7070c8.ts.net"
      "100.90.39.89"
    ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHe46Cikj0EbAbpOYFJmufQ2QcrOisZtbZL9q5gHmGJa";
  };

  age.secrets.harmonia-signing-key = {
    file = ../../modules/secrets/harmonia-signing-key.age;
    # Root-owned on purpose. harmonia runs with DynamicUser=true, so there is
    # no persistent "harmonia" user for agenix to chown to at activation
    # time; the unit reads the key via LoadCredential= as root and hands it
    # to the dynamic user itself. Setting owner = "harmonia" here fails
    # activation with an unknown-user error.
    mode = "0400";
  };

  # shirakami serves its own store as a signed binary cache, so nanashi and
  # kanade can `ame fetch` a generation instead of rebuilding it. Bound to
  # the tailnet address only: harmonia has no authentication of its own, and
  # a binary cache is a store-path oracle, so it must not be on the LAN or
  # the open internet.
  #
  # The signing key's private half lives only here (agenix, above); the
  # public half goes in each client's trusted-public-keys, which is what
  # makes a tampered path get refused rather than installed.
  services.harmonia.cache = {
    enable = true;
    signKeyPaths = [ config.age.secrets.harmonia-signing-key.path ];
    settings = {
      bind = "100.103.1.34:5000"; # this host's tailscale IPv4
      priority = 30; # below cache.nixos.org (40) so upstream wins for shared paths
    };
  };
  # harmonia needs to read the store as a client of the daemon. DynamicUser
  # allocates it at runtime, so trust it by name here.
  nix.settings.trusted-users = [ "harmonia" ];

  home-manager.users.kaitotlex =
    { lib, ... }:
    {
      # btop numbers NVML devices first, so GPU0 is the RTX and GPU1 is the iGPU.
      programs.btop = {
        package = pkgs.btop.override {
          cudaSupport = true;
          rocmSupport = true;
        };
        settings = {
          show_gpu_info = "On";
          custom_gpu_name1 = "Radeon 610M";
        };
      };

      functorOS.utils.audio.enable = false;

      systemd.user.services.xwayland-satellite = {
        Unit = {
          Description = "Xwayland outside your Wayland";
          BindsTo = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
          Requisite = [ "graphical-session.target" ];
          # scroll has its own Xwayland; this would only take :0 away from it.
          ConditionEnvironment = "XDG_CURRENT_DESKTOP=niri";
        };
        Service = {
          Type = "notify";
          NotifyAccess = "all";
          ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite";
          StandardOutput = "journal";
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };

      systemd.user.sessionVariables.DISPLAY = ":0";
      programs.niri.settings.outputs."Microstep MSI G274 CC2H032401304" = {
        mode = {
          width = 1920;
          height = 1080;
          refresh = 165.001;
        };
        position = {
          x = 0;
          y = 0;
        };
        focus-at-startup = true;
      };
      # What dms/outputs.kdl had for this monitor. modules/scroll.nix reads
      # these for the scroll session too.
      programs.niri.settings.outputs."ASUSTek COMPUTER INC VG34VQL3A W2LMDW010828" = {
        mode = {
          width = 3440;
          height = 1440;
          refresh = 165.001;
        };
        position = {
          x = 0;
          y = 0;
        };
      };
      # dms/outputs.kdl again, by connector: no make/model on record for these.
      # No position, so sway-style auto placement keeps them from overlapping.
      wayland.windowManager.scroll.config.output = {
        DP-1.mode = "2560x1440@180.001Hz";
        DP-2.mode = "2560x1440@180.001Hz";
      };

      #programs.dank-material-shell.settings = lib.mkForce {
      #  batteryChargeLimit = 98;
      #};
      #programs.niri.settings = {
      #  input.touchpad.tap = lib.mkForce true;
      #  outputs = {
      #     "Acer Technologies QG221Q TGGTT0018512" = {
      #       mode = {
      #         width = 1920;
      #         height = 1080;
      #         refresh = 60.0;
      #       };
      #       transform.rotation = 270;
      #       position = {
      #         x = 1920;
      #        y = 0;
      #};
      #};
    };
}

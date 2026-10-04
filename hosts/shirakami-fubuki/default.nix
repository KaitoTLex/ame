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
    kernelPackages = pkgs.linuxPackages_7_1;
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
  services.tailscale.enable = true;
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

  environment.systemPackages = with pkgs; [
    ryzenadj
    linuxPackages_zen.cpupower
    stress-ng

    config.services.llama-cpp.package
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
    inputs.nix-xilinx.overlay
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
  # llama-server pulls the GGUF (and its mmproj, for vision) from Hugging Face
  # into /var/cache/llama-cpp on first start.
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp.override { cudaSupport = true; };
    settings = {
      hf-repo = "huihui-ai/Huihui-Qwen3.8-27B-abliterated-GGUF:UD-IQ4_XS";
      alias = "qwen3.8-27b-abliterated";
      ctx-size = 65536;
      flash-attn = "on";
      jinja = true;
      # Internal; clients use the socket-activated proxy below.
      port = 8081;
    };
  };

  # Run llama-server on demand rather than always holding the GPU: the first
  # connection to 127.0.0.1:8080 starts the proxy, which pulls up llama-cpp;
  # after 10 idle minutes the proxy exits and llama-cpp stops with it.
  systemd.services.llama-cpp = {
    wantedBy = lib.mkForce [ ];
    unitConfig.StopWhenUnneeded = true;
    serviceConfig = {
      # Only count as started once the model is loaded, so the proxy never
      # forwards to a port nobody is listening on. The first start downloads
      # the GGUF, hence no start timeout.
      ExecStartPost = "${lib.getExe pkgs.curl} --silent --fail --retry 1000000 --retry-delay 2 --retry-all-errors --output /dev/null http://127.0.0.1:${toString config.services.llama-cpp.settings.port}/health";
      TimeoutStartSec = "infinity";
    };
  };
  systemd.sockets.llama-cpp-proxy = {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:8080" ];
  };
  systemd.services.llama-cpp-proxy = {
    requires = [ "llama-cpp.service" ];
    after = [ "llama-cpp.service" ];
    serviceConfig = {
      ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd --exit-idle-time=10min 127.0.0.1:${toString config.services.llama-cpp.settings.port}";
      DynamicUser = true;
    };
  };

  users.users.kaitotlex.linger = true;

  age.secrets.hermes-matrix-env = {
    file = ../../modules/secrets/hermes-matrix-env.age;
    owner = "kaitotlex";
    group = "users";
    mode = "0400";
  };

  home-manager.users.kaitotlex =
    { lib, ... }:
    let
      localModel = config.services.llama-cpp.settings.alias;
      llamaCppProvider = {
        name = "Local llama.cpp";
        api = "http://${lib.head config.systemd.sockets.llama-cpp-proxy.listenStreams}/v1";
        transport = "chat_completions";
        default_model = localModel;
        models.${localModel} = {
          context_length = config.services.llama-cpp.settings.ctx-size;
          supports_vision = true;
        };
      };
      # The `marine` profile itself is created with `hermes profile create`
      # (like `suisei`); only its model wiring is managed here, deep-merged into
      # the profile's config.yaml the same way the module merges the default one.
      marineSettings = {
        model = {
          provider = "custom:llama-cpp-local";
          default = localModel;
        };
        providers.llama-cpp-local = llamaCppProvider;
        # Long-running builder: nix builds and compiles outlive the 180s default.
        agent.max_turns = null;
        terminal = {
          cwd = "/home/kaitotlex";
          timeout = 3600;
        };
      };
      configMerge = import "${inputs.hermes-agent}/nix/configMergeScript.nix" { inherit pkgs; };
    in
    {
      home.packages = [
        (pkgs.writeShellScriptBin "senchou" ''exec hermes -p marine "$@"'')
      ];

      home.activation.hermesMarineProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        marine="$HOME/.hermes/profiles/marine"
        if [ -d "$marine" ]; then
          run ${configMerge} ${pkgs.writeText "hermes-marine.json" (builtins.toJSON marineSettings)} "$marine/config.yaml"
        fi
      '';

      imports = [ inputs.hermes-agent.homeManagerModules.default ];

      programs.hermes-agent.enable = true;
      services.hermes-agent = {
        enable = true;
        gateway.enable = true;
        package = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.minimal;
        extraDependencyGroups = [
          "anthropic"
          "matrix"
        ];
        environmentFiles = [ config.age.secrets.hermes-matrix-env.path ];
        environment = {
          MATRIX_E2EE_MODE = "required";
          MATRIX_HOMESERVER = "https://matrix.functor.systems";
        };
        settings = {
          model = {
            provider = "anthropic";
            default = "claude-opus-5";
          };
          providers.llama-cpp-local = llamaCppProvider;
          delegation = {
            provider = "custom:llama-cpp-local";
            model = localModel;
            max_concurrent_children = 1;
            fallback_providers = [ ];
          };
          platforms.matrix.enabled = true;
          matrix = {
            allowed_users = [
              "@kaitotlex:matrix.org"
              "@kaitotlex26:functor.systems"
            ];
            require_mention = false;
            process_notices = false;
            session_scope = "room";
            auto_thread = false;
            dm_mention_threads = false;
            max_message_length = 16000;
          };
          group_sessions_per_user = true;
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

# shirakami-fubuki: Mini-ITX desktop, Ryzen 7 7800X3D, NVIDIA dGPU (PRIME
# offload) next to the AMD GPU. Daily driver, local LLM box, and the machine
# that builds and deploys the rest of the fleet.
#
#   hardware-configuration.nix  generated
#   drives.nix       secondary LUKS/btrfs drives (setup-drives.sh formats them)
#   network.nix      tailscale, firewall, sshd, eduroam
#   graphics.nix     NVIDIA PRIME offload, VRAM leak cap, displays, Xwayland
#   llm.nix          on-demand llama.cpp (llama-gate.py) and the gamemode hooks
#   fleet.nix        `ame`: build every host here and push it out over tailscale
#   hermes.nix       Hermes Agent gateway on Matrix, local-model profiles
inputs:
{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./drives.nix
    ./network.nix
    ./graphics.nix
    ./llm.nix
    ./fleet.nix
    (import ./hermes.nix inputs)
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
    kernelPackages = pkgs.linuxPackages_7_2;
    kernelModules = [ "uinput" ];
    kernelParams = [ "amd_pstate=active" ];
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };

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

  security.rtkit.enable = true;
  users.users.futabatlex.shell = lib.mkForce pkgs.zsh;

  environment.systemPackages = with pkgs; [
    ryzenadj
    linuxPackages_zen.cpupower
    stress-ng
  ];
  nixpkgs.config.allowUnfree = true;

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

  nixpkgs.overlays = lib.mkAfter [
    inputs.nix-xilinx.overlay
  ];
  programs.steam.enable = true;
  functorOS = {
    theming = {
      wallpaper = "${inputs.wallpapers}/math/watsonbif.png";
      polarity = "light";
      base16Scheme = ../../assets/schemes/watson.yaml;
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

  home-manager.users.kaitotlex.functorOS.utils.audio.enable = false;
}

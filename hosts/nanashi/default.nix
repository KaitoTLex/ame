inputs:
{
  pkgs,
  lib,
  config,
  modulesPath,
  ...
}:
let
  # Imperative Xilinx install root and release. The nix-xilinx FHS wrappers
  # read these from ~/.config/xilinx/nix.sh (declared in the home-manager
  # block below); the layout is $INSTALL_DIR/$VERSION/Vivado/bin/vivado.
  xilinxInstallDir = "/home/kaitotlex/xilinx";
  xilinxVersion = "2025.2";
in
{
  imports = [
    "${modulesPath}/installer/scan/not-detected.nix"
    ../../modules/eduroam.nix
  ];

  # ---------------------------------------------------------------------------
  # ASUS TUF Gaming A14 (2026) FA401GM, iGPU-only unit
  #   Ryzen AI 9 465 (Zen 5, 10c/20t, Radeon 880M iGPU). No discrete GPU in
  #   this unit even though the ASUS spec page lists RTX 5060 SKUs, so this
  #   host is pure AMD graphics: no hardware.nvidia, no PRIME, no supergfxd.
  #   14" 2560x1600 165 Hz, 2x M.2 NVMe, USB4, WiFi 6E, microSD (rtsx).
  # This host deliberately has no hardware-configuration.nix; everything that
  # nixos-generate-config would emit lives here.
  # ---------------------------------------------------------------------------
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "thunderbolt"
      "usb_storage"
      "usbhid"
      "sd_mod"
      "rtsx_pci_sdmmc"
    ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-amd" ];
    extraModulePackages = [ ];
    kernelPackages = pkgs.linuxPackages_7_1;
    # Bring-up (remove once nanashi boots reliably): print stage-1 unit status
    # behind Plymouth (press Esc) so a failing unit is visible. mkAfter places
    # this after functorOS's rd.systemd.show_status=false; systemd keeps the
    # last value on the command line.
    kernelParams = lib.mkAfter [
      "amd_pstate=active"
      "rd.systemd.show_status=true"
    ];
    # Bring-up: kernel warnings on the console as well (functorOS forces 0).
    consoleLogLevel = lib.mkForce 4;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 15;
    };
  };

  # Disk layout mirrors shirakami-fubuki (LUKS -> btrfs, subvolumes for /home
  # and /nix) but is addressed by GPT partition labels so nothing has to be
  # pasted in after install. From the installer:
  #   parted /dev/nvme0n1 -- mklabel gpt
  #   parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB set 1 esp on
  #   parted /dev/nvme0n1 -- mkpart cryptroot 1GiB 100%
  #   mkfs.fat -F32 -n BOOT /dev/disk/by-partlabel/ESP
  #   cryptsetup luksFormat /dev/disk/by-partlabel/cryptroot
  #   cryptsetup open /dev/disk/by-partlabel/cryptroot cryptroot
  #   mkfs.btrfs -L nixos /dev/mapper/cryptroot
  #   mount /dev/mapper/cryptroot /mnt
  #   btrfs subvolume create /mnt/home && btrfs subvolume create /mnt/nix
  #   mount -o subvol=home /dev/mapper/cryptroot /mnt/home
  #   mount -o subvol=nix  /dev/mapper/cryptroot /mnt/nix
  #   mount --mkdir /dev/disk/by-partlabel/ESP /mnt/boot
  #   nixos-install --flake .#nanashi
  boot.initrd.luks.devices.cryptroot.device = "/dev/disk/by-partlabel/cryptroot";
  # Bring-up: a stage-1 failure opens a root shell instead of a locked sulogin
  # prompt. Set back to false once the machine is stable.
  boot.initrd.systemd.emergencyAccess = true;
  fileSystems = {
    "/" = {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
    };
    "/home" = {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };
    "/nix" = {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      options = [ "subvol=nix" ];
    };
    "/boot" = {
      device = "/dev/disk/by-partlabel/ESP";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };
  swapDevices = [ ];

  # ASUS platform daemon: fan curves / platform profiles / keyboard backlight /
  # charge limit. It keeps its own state under /etc, so it is left unmanaged
  # here. Set the battery limit once with `asusctl -c 90`; asusd remembers it.
  # supergfxd is deliberately absent: it only switches dGPU modes.
  services.asusd.enable = true;
  services.fwupd.enable = true;

  services.tailscale.enable = true;
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ config.services.tailscale.interfaceName ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];
  systemd.network.wait-online.enable = false;
  boot.initrd.systemd.network.wait-online.enable = false;
  security.rtkit.enable = true;

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

  # Vivado: nix-xilinx provides FHS wrappers around an imperative install.
  # First run `xilinx-shell`, unpack the FPGA*.tar from AMD inside it and run
  # `./xsetup -b ConfigGen`, then edit ~/.Xilinx/install_config.txt so
  # Destination matches xilinxInstallDir above and `./xsetup -a XilinxEULA=1
  # -a 3rdPartyEULA=1 -c ~/.Xilinx/install_config.txt -b Install`. After that
  # `vivado` on PATH launches it; `fix-desktop-entries` repoints the
  # installer's .desktop files at the wrapper so it shows up in the launcher.
  # The Digilent/FTDI/pcusb udev rules come from modules/hardware.
  nixpkgs.overlays = lib.mkAfter [
    inputs.nix-xilinx.overlay
  ];
  environment.systemPackages = with pkgs; [
    xilinx-shell
    vivado
    vlm
    xsct
    fix-desktop-entries
  ];

  programs.steam.enable = true;
  nixpkgs.config.allowUnfree = true;

  functorOS = {
    theming = {
      wallpaper = "${inputs.wallpapers}/anime/plana.jpg";
      polarity = "dark";
      base16Scheme = ../../scheme/plana.yaml;
    };
    system = {
      networking = {
        firewallPresets.vite = true;
      };
    };
    extras.gaming = {
      enable = true;
    };
  };

  home-manager.users.kaitotlex = {
    # Vivado is an X11 app (the wrapper forces GDK_BACKEND=x11, DISPLAY=:0),
    # so keep the same xwayland-satellite service shirakami-fubuki uses.
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

    home.file.".config/xilinx/nix.sh".text = ''
      export INSTALL_DIR=${xilinxInstallDir}
      export VERSION=${xilinxVersion}
    '';

    programs.niri.settings.outputs."eDP-1" = {
      mode = {
        width = 2560;
        height = 1600;
        refresh = 165.0;
      };
      scale = 1.25;
    };
  };
}

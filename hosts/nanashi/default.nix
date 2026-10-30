inputs:
{
  pkgs,
  lib,
  config,
  modulesPath,
  ...
}:
let
  # Read by the nix-xilinx wrappers via ~/.config/xilinx/nix.sh (see below).
  xilinxInstallDir = "/home/kaitotlex/xilinx";
  xilinxVersion = "2026.1";
in
{
  imports = [
    "${modulesPath}/installer/scan/not-detected.nix"
    ../../modules/eduroam.nix
    ../../modules/deploy-target.nix
    # Trust shirakami's harmonia cache so `ame fetch` can substitute a
    # generation instead of rebuilding it.
    ../../modules/ame-cache-client.nix
  ];

  # ASUS TUF Gaming A14 (FA401EA): Ryzen AI MAX+ 392 / Radeon 8060S, iGPU only
  # (no nvidia/PRIME/supergfxd). nvme0n1 is this install; nvme1n1 is Kubuntu.
  # No hardware-configuration.nix: that config lives here.
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "thunderbolt"
      "usb_storage"
      "uas"
      "usbhid"
      "sd_mod"
      "rtsx_pci_sdmmc"
    ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-amd" ];
    # Out-of-tree fixes for internal audio and post-hibernate GPU lock-ups.
    extraModulePackages = [
      (config.boot.kernelPackages.callPackage ./snd-acp-config.nix { })
      (config.boot.kernelPackages.callPackage ./ttm-swapout-fix.nix { })
    ];
    # Pinned 7.1, see nixpkgs-linux71 in flake.nix.
    kernelPackages =
      inputs.nixpkgs-linux71.legacyPackages.${pkgs.stdenv.hostPlatform.system}.linuxPackages_7_1;
    # EPP is driven by power-profiles-daemon; don't add a cpufreq governor.
    kernelParams = lib.mkAfter [ "amd_pstate=active" ];
    # With no country set, every disconnect drops cfg80211 back to the world
    # regdom, which turns 6 GHz off mid-roam. wpa_supplicant's 5-minute roam
    # to the AP's 6 GHz radio then always fails, and the disconnect/rescan
    # starves Bluetooth audio on this shared-antenna RTL8852CE.
    extraModprobeConfig = ''
      options cfg80211 ieee80211_regdom=US
    '';
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
  };

  # Set the native panel mode once, without an EFI-fb -> amdgpu flip mid-boot.
  hardware.amdgpu.initrd.enable = true;

  # LUKS -> btrfs (home/nix subvolumes), addressed by GPT partlabel. Install:
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
  fileSystems = {
    # noatime: relatime still wakes the NVMe once a day per file read.
    "/" = {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      options = [ "noatime" ];
    };
    "/home" = {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      options = [
        "subvol=home"
        "noatime"
      ];
    };
    "/nix" = {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      options = [
        "subvol=nix"
        "noatime"
      ];
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

  # Sleep. On lid open the EC also sends a power-button press, and that is the
  # only reliable wake source (_LID lags, so lid-only wake is a coin flip). The
  # button stays armed for wakeup and pressing it is made harmless:
  # HandlePowerKey = "ignore", plus niri's power-key handling off.
  services.udev.extraRules = ''
    # Power button only; the lid switch is also acpi-button, hence KERNEL match.
    ACTION=="add|change", SUBSYSTEM=="platform", KERNEL=="PNP0C0C:00", ATTR{power/wakeup}="enabled"
  '';

  # Hibernation swapfile. No resume= / resume_offset on purpose: systemd-sleep
  # stores the location in the HibernateLocation EFI variable.
  swapDevices = [
    {
      device = "/swapfile";
      size = 32768; # MiB
    }
  ];

  services.logind.settings.Login = {
    # Holding the button for 4 s still cuts power.
    HandlePowerKey = "ignore";
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    HandleLidSwitchDocked = "ignore";
  };

  systemd.sleep.settings.Sleep = {
    SuspendState = "freeze"; # no S3 on this platform
    HibernateDelaySec = "30min";
  };

  # asusd keeps its own state; set the charge limit once with `asusctl -c 80`.
  services.asusd.enable = true;
  services.fwupd.enable = true;

  # scroll next to niri. Same DMS, same keymap, zero gaps. modules/scroll.nix.
  functorOS.desktop.scroll.enable = true;

  services.tailscale.enable = true;
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ config.services.tailscale.interfaceName ];
    allowedUDPPorts = [
      config.services.tailscale.port
      2021 # Bambu printers' SSDP announcements (LAN discovery)
    ];
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
          # ASUS/Armoury key. keyd may not grab the WMI hotkey device, so niri
          # also binds XF86Launch1 below; either way it's play/pause.
          prog1 = "playpause";
        };
      };
    };
  };

  programs.xwayland.enable = true;

  # Vivado (imperative install): run AMD's installer inside `xilinx-shell`
  # with Destination = xilinxInstallDir, then `fix-desktop-entries`.
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
  # JTAG cable access for hw_server: the rules Vivado's install_drivers would
  # copy to /etc/udev/rules.d (data/xicom/cable_drivers/lin64/install_script).
  # The FTDI rule detaches ftdi_sio so hw_server can claim the chip.
  services.udev.packages = lib.singleton (
    pkgs.writeTextDir "lib/udev/rules.d/52-xilinx-cables.rules" ''
      # 52-xilinx-digilent-usb.rules
      ATTRS{idVendor}=="1443", MODE:="666"
      ACTION=="add", ATTRS{idVendor}=="0403", ATTRS{manufacturer}=="Digilent", MODE:="666"
      # 52-xilinx-ftdi-usb.rules
      ATTRS{idVendor}=="0403", ATTRS{bInterfaceNumber}=="00", PROGRAM="/bin/sh -c 'echo -n $id:1.0 > /sys/bus/usb/drivers/ftdi_sio/unbind; echo -n $id:1.1 > /sys/bus/usb/drivers/ftdi_sio/unbind'"
      ACTION=="add", ATTRS{idVendor}=="0403", MODE:="666"
      # 52-xilinx-pcusb.rules
      ATTR{idVendor}=="03fd", ATTR{idProduct}=="0008", MODE="666"
      ATTR{idVendor}=="03fd", ATTR{idProduct}=="0007", MODE="666"
      ATTR{idVendor}=="03fd", ATTR{idProduct}=="0009", MODE="666"
      ATTR{idVendor}=="03fd", ATTR{idProduct}=="000d", MODE="666"
      ATTR{idVendor}=="03fd", ATTR{idProduct}=="000f", MODE="666"
      ATTR{idVendor}=="03fd", ATTR{idProduct}=="0013", MODE="666"
      ATTR{idVendor}=="03fd", ATTR{idProduct}=="0015", MODE="666"
    ''
  );

  # Upstream's Flathub build: nixpkgs' bambu-studio lags upstream releases.
  services.flatpak.packages = [ "com.bambulab.BambuStudio" ];
  # Exits 255 at startup on native Wayland; run it through xwayland-satellite.
  services.flatpak.overrides."com.bambulab.BambuStudio" = {
    Context.sockets = [ "x11" ];
    Environment.GDK_BACKEND = "x11";
  };

  programs.steam.enable = true;
  nixpkgs.config.allowUnfree = true;

  functorOS = {
    theming = {
      wallpaper = "${inputs.wallpapers}/vtubers/uiDate.jpg";
      polarity = "dark";
      base16Scheme = ../../scheme/shigure-ui.yaml;
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
    # For Vivado, which is X11-only.
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

    # DMS, not logind, owns idle sleep. On battery, match the lid
    # (2 = SuspendThenHibernate).
    programs.dank-material-shell.settings.batterySuspendBehavior = lib.mkForce 2;

    programs.niri.settings = {
      # Otherwise niri re-suspends on the EC's lid-open power press (see Sleep).
      input.power-key-handling.enable = false;

      outputs."eDP-1" = {
        mode = {
          width = 2560;
          height = 1600;
          refresh = 165.0;
        };
        scale = 1.25;
      };

      # ASUS VG34VQL3A ultrawide, matched by make/model/serial so it follows the
      # monitor across connectors. Its HDMI inputs are 2.0 and stop at 100 Hz;
      # 165+ (it does 180) needs DisplayPort, i.e. a USB-C -> DP cable.
      # A dms/outputs.kdl block for the same connector shadows this one
      # (niri takes the first matching output block).
      outputs."ASUSTek COMPUTER INC VG34VQL3A W2LMDW010828" = {
        # No refresh: niri picks the highest the link offers.
        mode = {
          width = 3440;
          height = 1440;
        };
        position = {
          x = 0;
          y = 0;
        };
        # Open windows at a third, so three tile the screen exactly (niri's
        # proportions already account for gaps). The global presets
        # (1/3, 1/2, 2/3) still apply for switch-preset-column-width.
        layout.default-column-width.proportion = 1.0 / 3.0;
      };

      input.touchpad = {
        tap = lib.mkForce true; # functorOS defaults to false
        tap-button-map = "left-right-middle";
        click-method = "clickfinger";
        dwt = true;
      };

      binds = {
        # ASUS/Armoury key (KEY_PROG1) -> play/pause, also on the lock screen.
        "XF86Launch1" = {
          allow-when-locked = true;
          action.spawn-sh = "${lib.getExe pkgs.playerctl} --player=%any,firefox play-pause";
        };
      };
    };
  };
}

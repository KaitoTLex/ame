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
  # ASUS TUF Gaming A14, board/product FA401EA (DMI: ASUS / "TUF Gaming A14",
  # BIOS FA401EA.301). Verified against the running machine, not the spec page:
  #
  #   CPU   AMD Ryzen AI MAX+ 392 "Strix Halo", 12C/24T, boost 3.2 GHz
  #   GPU   Radeon 8060S (Strix Halo, PCI 1002:1586 @ 65:00.0), 40 CUs.
  #         iGPU only -- there is no discrete GPU in this unit, so there is no
  #         hardware.nvidia, no PRIME and no supergfxd anywhere in this file.
  #   RAM   30 GiB usable (LPDDR5X, soldered -- shared with the iGPU)
  #   Disk  nvme0n1 Micron 2600 1 TB   -> ESP + LUKS/btrfs, this install
  #         nvme1n1 SM2268XT     512 GB -> a separate Kubuntu install, untouched
  #   Net   Realtek RTL8852CE Wi-Fi 6E (rtw89) + RTL8852CU Bluetooth over USB
  #   Panel eDP-1, 2560x1600 @ 165 Hz
  #   Input i2c-HID touchpad ASCF1206:00 (2808:0250), ASUS WMI hotkey block
  #   Other USB4/Thunderbolt host router, microSD (rtsx_pci_sdmmc), no dGPU
  #
  # This host deliberately has no hardware-configuration.nix; everything that
  # nixos-generate-config would emit lives here. (The generated file that used
  # to sit next to this one described a *different*, earlier ext4 install and
  # was never imported by flake.nix -- it has been deleted.)
  # ---------------------------------------------------------------------------
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
    extraModulePackages = [ ];
    kernelPackages = pkgs.linuxPackages_7_1;
    # amd-pstate in active mode hands frequency/EPP selection to the CPU's own
    # governor, which is what power-profiles-daemon (enabled by functorOS for
    # formFactor = "laptop") drives. This is the lowest-idle-power arrangement
    # on Zen 5 mobile; do not add a cpufreq governor on top of it.
    kernelParams = lib.mkAfter [ "amd_pstate=active" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      # 15 s was a bring-up convenience. Every second here is spent at full
      # firmware power draw with the panel lit.
      timeout = 3;
    };
  };

  # Load amdgpu from the initrd so the panel is brought up once, at its native
  # mode, instead of flipping from EFI-fb to native partway through boot.
  hardware.amdgpu.initrd.enable = true;

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
  fileSystems = {
    # noatime everywhere: relatime still writes an atime back to disk on the
    # first read of a file each day, which wakes the NVMe for nothing.
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

  # ---------------------------------------------------------------------------
  # Sleep, hibernation, and the lid-close wakeup loop
  #
  # Symptom that started this: close the lid, come back, and the machine is
  # flickering and will not accept a password. It was never hibernating -- there
  # was no swap on this machine at all, so hibernation was impossible.
  #
  # What was happening (journal, 2026-09-22 00:22:55 -> 00:23:03): the ASUS EC
  # emits a phantom "Power key pressed short" ~2 s after the system enters
  # s2idle. The ACPI power button (PNP0C0C:00) is an armed wakeup source, so
  # every phantom press pulled the machine straight back out of s2idle; niri saw
  # the lid still shut and asked logind to suspend again, forever. Each cycle
  # tears the panel down and brings it back, which is the flicker, and the lock
  # screen never stays up long enough to type into.
  #
  # Disarming the power button did stop that loop -- and also left the laptop
  # impossible to wake. See the 12:15 boot: an idle suspend at 14:08:46 with the
  # lid already *open*, no resume, and a held-power-button power-off at 14:18
  # that cost the session. Pressing power is the one wake gesture that always
  # works on this chassis: the lid switch only fires on a state *change*, which
  # is no help when the lid never closed, and neither the i2c-HID touchpad nor
  # the i8042 keyboard reliably pulls this platform out of s2idle. So the power
  # button stays armed, below.
  #
  # The loop is broken at the other end instead:
  #   * HandlePowerKey = "ignore" -- the wakeup capability and the button
  #     *action* are independent knobs. A phantom press can wake the machine but
  #     can never suspend or power it off.
  #   * The lid is logind's to handle (HandleLidSwitch), and logind only acts on
  #     a lid state change. A phantom wake with the lid still shut does not
  #     re-trigger it. That is precisely what turned one spurious wake into a
  #     loop back when the compositor owned this path and re-checked lid state
  #     on every resume.
  #   * suspend-then-hibernate gives a lid left shut somewhere to land: after
  #     HibernateDelaySec the machine hibernates, and hibernation arms no wakeup
  #     sources at all for the EC to trip.
  #
  # If the flicker ever comes back, the escape hatch is to flip the rule below
  # to "disabled" -- but that trades away the ability to wake the machine, so
  # pair it with a wake source you have actually tested on this unit first.
  # ---------------------------------------------------------------------------
  services.udev.extraRules = ''
    # Keep the ACPI power button armed as a wakeup source explicitly, rather
    # than relying on the firmware default: it is the only dependable way back
    # out of s2idle here. Matched by KERNEL, not DRIVER -- the lid switch
    # PNP0C0D:00 is bound to acpi-button as well and is left alone.
    ACTION=="add|change", SUBSYSTEM=="platform", KERNEL=="PNP0C0C:00", ATTR{power/wakeup}="enabled"
  '';

  # 32 GiB swapfile, inside LUKS, for hibernation. 30 GiB of RAM, and the kernel
  # only writes ~2/5 of RAM by default, so this is generous.
  #
  # It lives at the top of the root subvolume on purpose: nothing snapshots it,
  # and `dirname` resolves to a btrfs mount, which makes NixOS's mkswap unit use
  # `btrfs filesystem mkswapfile` (NOCOW, no compression, correct extents)
  # instead of dd. The file is created automatically on the next boot.
  #
  # No boot.resumeDevice / resume_offset is set, and that is deliberate. This
  # host uses a systemd initrd, and systemd-sleep records the resume device and
  # physical offset in the HibernateLocation EFI variable at hibernate time,
  # which systemd-hibernate-resume reads back in stage 1. Putting a bare
  # `resume=` on the command line with no offset would point the kernel at byte
  # 0 of cryptroot instead, which is simply wrong.
  swapDevices = [
    {
      device = "/swapfile";
      size = 32768; # MiB
    }
  ];

  services.logind.settings.Login = {
    # Phantom power-key presses, see above -- never act on this key. This is
    # what makes it safe to leave the button armed as a wakeup source: a press
    # brings the machine back, and can do nothing else. Shut down from the
    # session menu or `systemctl poweroff`; holding the button for 4 s is still
    # a firmware-level cut and bypasses this entirely.
    HandlePowerKey = "ignore";
    # Shut lid: s2idle now, hibernate once HibernateDelaySec has passed. On a
    # closed laptop this is the single biggest battery saving available, because
    # hibernation draws nothing at all.
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    # Lid shut with an external display attached means "use the monitor".
    HandleLidSwitchDocked = "ignore";
  };

  systemd.sleep.settings.Sleep = {
    # This platform only offers s2idle; there is no S3 ("deep") in mem_sleep.
    SuspendState = "freeze";
    HibernateDelaySec = "30min";
  };

  # ASUS platform daemon: fan curves / platform profiles / keyboard backlight /
  # charge limit. It keeps its own state under /etc, so it is left unmanaged
  # here. Set the battery limit once with `asusctl -c 80`; asusd remembers it.
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
          # The ASUS/Armoury key on this keyboard. asus-nb-wmi reports it as
          # KEY_PROG1 (148) on the "Asus WMI hotkeys" device -- confirmed from
          # that device's capabilities/key bitmap, which carries 148 alongside
          # the rest of the ASUS hotkey block.
          #
          # keyd only binds devices it recognises as keyboards, and the WMI
          # hotkey device has no alphanumeric keys, so this rule may never fire.
          # The niri bind on XF86Launch1 (the X keysym for KEY_PROG1) in the
          # home-manager block below covers that case. Exactly one of the two
          # paths runs for any given press -- if keyd does grab the device it
          # rewrites the key to KEY_PLAYPAUSE, which niri already binds to
          # playerctl as XF86AudioPlay -- so they agree rather than conflict.
          prog1 = "playpause";
        };
      };
    };
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

    # The idle timeouts that actually put this machine to sleep come from
    # DankMaterialShell, not logind -- niri holds a logind inhibitor, so it is
    # DMS that calls Suspend() (journal: "suspend requested from client
    # PID ... ('niri')"). Make its battery path agree with logind's lid path:
    # 2 = SuspendThenHibernate in DMS's SuspendBehavior enum.
    # On AC, leave it at plain suspend (0) -- resume is instant and there is no
    # battery to protect.
    programs.dank-material-shell.settings.batterySuspendBehavior = lib.mkForce 2;

    programs.niri.settings = {
      outputs."eDP-1" = {
        mode = {
          width = 2560;
          height = 1600;
          refresh = 165.0;
        };
        scale = 1.25;
      };

      input.touchpad = {
        # functorOS sets tap = false for its hosts; this one wants tap-to-click.
        tap = lib.mkForce true;
        # One finger = left, two = right, three = middle.
        tap-button-map = "left-right-middle";
        # Physically clicking the pad picks its button by finger count too,
        # so the bottom-right corner is not a dead "right-click zone".
        click-method = "clickfinger";
        # Ignore the pad while typing -- with tap on, a palm brush is a click.
        dwt = true;
      };

      binds = {
        # The ASUS/Armoury key -> play/pause. KEY_PROG1 reaches the compositor
        # as XF86Launch1. Mirrors functorOS's own XF86AudioPlay bind, plus
        # allow-when-locked so it works on the lock screen like the volume keys.
        "XF86Launch1" = {
          allow-when-locked = true;
          action.spawn-sh = "${lib.getExe pkgs.playerctl} --player=%any,firefox play-pause";
        };
      };
    };
  };
}

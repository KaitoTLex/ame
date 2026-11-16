# Server defaults for a box that stays up: never sleep, bounded journal, reboot
# on panic, BBR, disk health, key-only sshd. kronii had these under ServOS.
# Add headless.nix on a host with no monitor.
{
  pkgs,
  lib,
  ...
}:
{
  functorOS = {
    # Only "laptop" and "desktop" exist; config.nix says laptop.
    formFactor = lib.mkForce "desktop";
    # Forces NetworkManager on and points DNS at Cloudflare; the host brings its
    # own systemd-networkd instead.
    system.networking.enable = false;
  };

  networking.firewall.enable = true;
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      # Key-only root, for hosts that take deploys (see deploy-target.nix).
      PermitRootLogin = "prohibit-password";
    };
  };

  # A server must not fall asleep.
  systemd.targets =
    lib.genAttrs
      [
        "sleep"
        "suspend"
        "hibernate"
        "hybrid-sleep"
        "suspend-then-hibernate"
      ]
      (_: {
        enable = false;
      });
  services.logind.settings.Login = {
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";
    HandleLidSwitch = "ignore";
    IdleAction = "ignore";
  };

  services.journald.settings.Journal = {
    SystemMaxUse = "2G";
    MaxRetentionSec = "1month";
  };

  boot.kernel.sysctl = {
    # Reboot instead of sitting on a frozen console.
    "kernel.panic" = lib.mkDefault 10;
    "kernel.panic_on_oops" = lib.mkDefault 1;
    "vm.swappiness" = lib.mkDefault 10;
    # Beats nixpkgs' own mkDefault of 524288.
    "fs.inotify.max_user_watches" = lib.mkOverride 900 1048576;
    "fs.file-max" = lib.mkDefault 2097152;
    # Fair queueing + BBR keeps fast links saturated without bufferbloat.
    "net.core.default_qdisc" = lib.mkDefault "fq";
    "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr";
    "net.core.rmem_max" = lib.mkDefault 134217728;
    "net.core.wmem_max" = lib.mkDefault 134217728;
    "net.ipv4.tcp_rmem" = lib.mkDefault "4096 87380 134217728";
    "net.ipv4.tcp_wmem" = lib.mkDefault "4096 65536 134217728";
    "net.core.netdev_max_backlog" = lib.mkDefault 250000;
  };
  boot.kernelModules = [ "tcp_bbr" ];

  # Spread NIC/NVMe interrupts across cores.
  services.irqbalance.enable = true;

  services.smartd = {
    enable = true;
    autodetect = true;
  };
  services.fstrim.enable = true;
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };
  services.earlyoom.enable = true;

  documentation.nixos.enable = false;

  programs.mtr.enable = true;
  environment.systemPackages = with pkgs; [
    htop
    iotop-c
    sysstat
    pciutils
    usbutils
    smartmontools
    nvme-cli
    ethtool
    iperf3
    tcpdump
    dig
    tmux
    rsync
    jq
    ncdu
    tree
    fastfetch
  ];
}

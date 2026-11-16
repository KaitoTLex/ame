# kronii: Threadripper 9970X FPGA build server and print-farm hub, and since
# 2026-11 a desktop too: an ASUS VG34VQL3A ultrawide and a VG249 (1080p) hang
# off the Arc Pro B60, which is temporary; the RTX 3050 takes the monitors over
# when it goes. The passive Tesla V100 runs koyori's vision model (koyori.nix,
# cooling.nix). Formerly ServOS, then headless. The B60 used to serve a local
# LLM (llm.nix, bifrost.nix); that is switched off below.
#
# Built from this checkout: `nh os switch .` in ~/.config/ame (alias nixr).
# airi, koyori and osaka-greeter aren't published, so their checkouts only
# exist on kronii; flake.nix takes them as local inputs that only this host
# evaluates (see unpublished.nix). That is why kronii isn't in shirakami's
# `ame` host list: nothing else can resolve those inputs.
#
#   boot.nix         kernel and Secure Boot (lanzaboote)
#   storage.nix      btrfs mount options and scrubbing
#   network.nix      bonded LAN link, tailscale exit node, firewall
#   dns.nix          ad-blocking DNS for the tailnet (unbound + crab-hole)
#   ssh.nix          who can log in, as kaitotlex and as root
#   cooling.nix      NVIDIA driver and chassis fans (fantui.py)
#   desktop.nix      niri on the Arc, monitors, keyd, audio, gaming
#   llm.nix          llama.cpp on the B60
#   bifrost.nix      AI gateway (web UI, logs, virtual keys) in front of llm.nix
#   unpublished.nix  the three local inputs' modules, configured by
#     airi.nix         services.airi: Vivado and the bench harness
#     koyori.nix       services.koyori: the print-farm hub and detector
#     greeter.nix      services.osaka-greeter: login screen on the 1080p monitor
inputs:
{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/server.nix
    inputs.lanzaboote.nixosModules.lanzaboote
    ./boot.nix
    ./storage.nix
    ./network.nix
    ./dns.nix
    ./ssh.nix
    ./cooling.nix
    (import ./desktop.nix inputs)
    (import ./board.nix inputs)
    (import ./unpublished.nix inputs)
    ./llm.nix
    ./bifrost.nix
  ];

  # Installed on 26.05; modules/common.nix's 26.11 is for newer installs.
  system.stateVersion = lib.mkForce "26.05";

  functorOS.flakeLocation = lib.mkForce "/home/kaitotlex/.config/ame";

  # Suisei, like the scheme. Picked at random from the wallpapers input's Suisei
  # pictures on 2026-11-15 (anime/suiseiComets.jpg, math/Suibif.png and
  # vtubers/sui/* are the others); 1048x642, so it is scaled up on the ultrawide.
  functorOS.theming = {
    wallpaper = "${inputs.wallpapers}/anime/sui.jpg";
    polarity = "dark";
    base16Scheme = ../../assets/schemes/suisei.yaml;
  };

  # Synthesis/implementation runs want every core clocked up, and airi-bench
  # results assume it. With amd-pstate active this also pins EPP to
  # performance. power-profiles-daemon would fight the governor.
  powerManagement.cpuFreqGovernor = "performance";
  services.power-profiles-daemon.enable = lib.mkForce false;

  # ECC and PCIe error logging.
  hardware.rasdaemon.enable = true;

  environment.systemPackages = with pkgs; [
    # ssh from kitty (TERM=xterm-kitty) needs its terminfo here, for root too.
    kitty.terminfo
    sbctl
    numactl
    hwloc
    lm_sensors
    dmidecode
    edac-utils
    config.boot.kernelPackages.cpupower
    pre-commit
    # FPGA/HDL work; Vivado itself comes from airi.
    verilator
    gnumake
    cmake
    claude-code
  ];
}

# kronii: Threadripper 9970X FPGA build server. Headless (an Arc Pro B60 with
# nothing plugged in, plus a passive Tesla V100; see cooling.nix), formerly
# ServOS. The B60 serves a local LLM; see llm.nix.
#
# Everything imported here builds on any ame host. airi, koyori and
# osaka-greeter aren't published, so their checkouts only exist on kronii and
# can't be ame inputs (every `ame update` elsewhere would need them).
# unpublished.nix wraps them as `ame.nixosModules.kronii`; ~/Source/osaka on kronii is
# a small flake that passes its checkouts in and extends
# nixosConfigurations.kronii with it. That is what kronii actually builds from,
# and why kronii isn't in shirakami's `ame` host list.
#
#   boot.nix         kernel and Secure Boot (lanzaboote)
#   storage.nix      btrfs mount options and scrubbing
#   network.nix      bonded LAN link, tailscale exit node, firewall
#   dns.nix          ad-blocking DNS for the tailnet (unbound + crab-hole)
#   ssh.nix          who can log in, as kaitotlex and as root
#   cooling.nix      GPU drivers and chassis fans (fantui.py)
#   llm.nix          llama.cpp on the B60
#   bifrost.nix      AI gateway (web UI, logs, virtual keys) in front of llm.nix
#
# Applied by ~/Source/osaka through unpublished.nix, not imported here:
#   airi.nix         services.airi: Vivado and the bench harness
#   koyori.nix       services.koyori: the print-farm hub
#   greeter.nix      services.osaka-greeter: console login screen
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
    # The LLM stack on the Arc (llm.nix, bifrost.nix) is switched off; the files
    # stay so it can come back by uncommenting these two lines.
    # ./llm.nix
    # ./bifrost.nix
  ];

  # Installed on 26.05; modules/common.nix's 26.11 is for newer installs.
  system.stateVersion = lib.mkForce "26.05";

  functorOS.flakeLocation = lib.mkForce "/home/kaitotlex/Source/osaka";

  # Only the console and terminal tools get themed here; nanashi's scheme, so
  # ssh sessions from it look the same. The image is required but never shown,
  # so it's a small file from this repo rather than the wallpapers input.
  functorOS.theming = {
    wallpaper = ../../assets/watsonExe.jpeg;
    polarity = "dark";
    base16Scheme = ../../assets/schemes/shigure-ui.yaml;
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
    # FPGA/HDL work; Vivado itself comes from airi.
    verilator
    gnumake
    cmake
    claude-code
  ];
}

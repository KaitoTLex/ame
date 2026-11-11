inputs:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  vix = inputs.nixvim.packages.${pkgs.stdenv.targetPlatform.system}.default;
  kaitoPkgs = import ../pkgs/default.nix {
    inherit pkgs;
    system = pkgs.stdenv.targetPlatform.system;
  };
in
{
  imports = [
    ../modules/hardware
    ../modules/functorOSmods
    # functorOS.desktop.scroll: swap niri for scroll, keep DMS and the keymap.
    (import ../modules/scroll.nix { inherit inputs; }).nixos
    ../modules/unifi-endpoint
  ];

  # time.timeZone = "America/Los_Angeles";
  time.timeZone = "America/New_York";
  # time.timeZone = "Asia/Taipei";
  # time.timeZone = "Asia/Tokyo";
  system.stateVersion = "26.11";
  nixpkgs.config.allowUnfree = true;
  # gtk2 is marked broken ahead of its removal (nixpkgs#410814), but Vivado
  # still loads it from nix-xilinx's xilinx-shell FHS env. Warn, don't refuse.
  nixpkgs.config.problems.handlers."gtk+".broken = "warn";
  # Kernel-module aggregator: tolerate modules without signing certs. See the file.
  nixpkgs.overlays = [ (import ../modules/kmod-aggregator-fix.nix) ];

  # kaitoPkgs is mostly desktop apps; headless hosts pick their own tools.
  environment.systemPackages = [ vix ] ++ lib.optionals config.functorOS.desktop.enable kaitoPkgs;

  users.users.kaitotlex.extraGroups = [ "dialout" ];

  # PipeWire's X11 bell module segfaults when its display goes away, so every
  # Xwayland exit took all the audio down with it. Nothing here needs the bell.
  services.pipewire.extraConfig.pipewire."99-no-x11-bell"."context.properties"."module.x11.bell" =
    false;

  functorOS = {
    flakeLocation = "/home/kaitotlex/.config/ame";
    config.allowUnfree = true;
    defaultEditor = vix;
    formFactor = "laptop";
    desktop.localization.chinese = {
      input.enable = true;
      script = "traditional";
    };
    system = {
      audio.prod.enable = false;
      networking.cloudflareNameservers.enable = true;
    };
  };
}

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
    # functorOS at the pin vs current nixpkgs: see the file.
    (import ../modules/functorOS-fixes.nix { inherit inputs; })
    # functorOS.desktop.scroll: swap niri for scroll, keep DMS and the keymap.
    (import ../modules/scroll.nix { inherit inputs; }).nixos
  ];

  # time.timeZone = "America/Los_Angeles";
  time.timeZone = "America/New_York";
  # time.timeZone = "Asia/Taipei";
  # time.timeZone = "Asia/Tokyo";
  system.stateVersion = "26.11";
  nixpkgs.config.allowUnfree = true;
  # Kernel-module aggregator: tolerate modules without signing certs. See the file.
  nixpkgs.overlays = [ (import ../modules/kmod-aggregator-fix.nix) ];

  # kaitoPkgs is mostly desktop apps; headless hosts pick their own tools.
  environment.systemPackages = [ vix ] ++ lib.optionals config.functorOS.desktop.enable kaitoPkgs;

  users.users.kaitotlex.extraGroups = [ "dialout" ];

  # command-not-found reads programs.sqlite from the `nixos` channel, which a
  # flake system never has, so every typo printed "Missing package database".
  # nix-index (prebuilt DB, from functorOS's nix-index-database) handles it instead.
  programs.command-not-found.enable = lib.mkForce false;

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

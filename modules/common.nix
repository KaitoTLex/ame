# Shared by every host. flake.nix imports this first, then hosts/<name>, which
# may override anything here.
inputs:
{
  pkgs,
  lib,
  ...
}:
let
  vix = inputs.nixvim.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  imports = [
    ./hardware
    ./functorOSmods
    ./desktop-packages
  ];

  # time.timeZone = "America/Los_Angeles";
  time.timeZone = "America/New_York";
  # time.timeZone = "Asia/Taipei";
  # time.timeZone = "Asia/Tokyo";
  system.stateVersion = "26.11";
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = [ vix ];

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

# Shared NixOS configuration for all machines (kuroko, mafuyu, kanade).
# Import as: (import ./commonConfig.nix inputs)
inputs:
{ pkgs, lib, ... }:
let
  vix = inputs.nixvim.packages.${pkgs.stdenv.targetPlatform.system}.default;
  kaitoPkgs = import ./pkgs/default.nix {
    inherit pkgs;
    system = pkgs.stdenv.targetPlatform.system;
  };
in
{
  imports = [ ./hardware ];

  time.timeZone = "America/Los_Angeles";
  system.stateVersion = "25.11";
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = [ vix ] ++ kaitoPkgs;

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

inputs:
{ pkgs, lib, config, ... }:
let
  vix = inputs.nixvim.packages.${pkgs.stdenv.targetPlatform.system}.default;
  kaitoPkgs = import ./pkgs/default.nix {
    inherit pkgs;
    system = pkgs.stdenv.targetPlatform.system;
  };
in
{
  imports = [ ./modules/hardware ];

  # time.timeZone = "America/Los_Angeles";
  time.timeZone = "Asia/Taipei";
  system.stateVersion = "26.11";
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = [ vix ] ++ kaitoPkgs;

  users.users.kaitotlex.extraGroups = [ "dialout" ];

  # GitHub access token for fetching the private nixflake input. The secret
  # file itself is a plain `access-tokens = github.com=<token>` nix.conf
  # line, included at build time so the token never lands in the store.
  age.secrets.github-token.file = ./modules/secrets/github-token.age;
  nix.extraOptions = ''
    !include ${config.age.secrets.github-token.path}
  '';

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

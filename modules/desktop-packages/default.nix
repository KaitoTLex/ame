# Desktop apps for every graphical host, split into a common list and a
# per-architecture one. Headless hosts (kronii) pick their own tools instead.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  common = import ./common.nix { inherit pkgs; };
  perArch = {
    x86_64-linux = import ./x86_64-linux.nix { inherit pkgs; };
    aarch64-linux = import ./aarch64-linux.nix { inherit pkgs; };
  };
  arch = perArch.${pkgs.stdenv.hostPlatform.system} or [ ];
in
{
  environment.systemPackages = lib.mkIf config.functorOS.desktop.enable (common ++ arch);
}

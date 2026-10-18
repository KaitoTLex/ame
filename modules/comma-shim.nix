# functorOS's shellenv sets `programs.comma.enable` and
# `programs.command-not-found.enable`, but it dropped nix-index-database:
#  - nothing declares `programs.comma.enable`, so declare it here and route it
#    to nix-index-database's prebuilt-db comma;
#  - command-not-found needs the `nixos` channel's programs.sqlite, which a
#    flake system never has ("Missing package database" on every typo), so
#    force it off and let nix-index's handler (also prebuilt-db) take over.
inputs:
{
  config,
  lib,
  ...
}:
{
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  options.programs.comma.enable = lib.mkEnableOption "comma";

  config = {
    programs.nix-index-database.comma.enable = config.programs.comma.enable;
    programs.command-not-found.enable = lib.mkForce false;
    programs.nix-index.enable = true;
  };
}

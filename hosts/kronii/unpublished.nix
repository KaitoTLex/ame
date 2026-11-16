# kronii's services whose code isn't published anywhere: airi (Vivado layer and
# bench harness), koyori (print-farm hub) and osaka-greeter (console login
# screen). Their checkouts exist on kronii alone, so flake.nix takes them as
# local path/git inputs (airi, koyori, osaka-greeter), which only kronii ever
# evaluates. This file imports their NixOS modules and the settings for them,
# which live next to the rest of the host config:
#
#   airi.nix     services.airi: Vivado install, hw_server, bench
#   koyori.nix   services.koyori: hub, cameras, detector, access
#   greeter.nix  services.osaka-greeter
inputs:
{ ... }:
{
  imports = [
    inputs.airi.nixosModules.default
    "${inputs.koyori}/nix/module.nix"
    "${inputs.osaka-greeter}/nix/module.nix"
    ./airi.nix
    ./koyori.nix
    ./greeter.nix
  ];
}

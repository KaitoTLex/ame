# kronii's services whose code isn't published anywhere: airi (Vivado layer and
# bench harness) and koyori (print-farm hub). Their checkouts exist on kronii
# alone, so flake.nix takes them as local path/git inputs (airi, koyori), which
# only kronii ever evaluates. This file imports their NixOS modules and the
# settings for them, which live next to the rest of the host config:
#
#   airi.nix     services.airi: Vivado install, hw_server, bench
#   koyori.nix   services.koyori: hub, cameras, detector, access
inputs:
{ ... }:
{
  imports = [
    inputs.airi.nixosModules.default
    "${inputs.koyori}/nix/module.nix"
    ./airi.nix
    ./koyori.nix
  ];
}

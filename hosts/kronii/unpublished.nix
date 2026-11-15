# kronii's services whose code isn't published anywhere: airi (Vivado layer and
# bench harness), koyori (print-farm hub) and osaka-greeter (console login
# screen). Their checkouts only exist on kronii, so they can't be ame inputs:
# every other host would then need them too, and `ame update` would fail
# without them.
#
# Exposed as `ame.nixosModules.kronii`, a function from those three flakes to
# a NixOS module. ~/Source/osaka on kronii is a small flake that has the checkouts as
# inputs and does
#
#   ame.nixosConfigurations.kronii.extendModules {
#     modules = [ (ame.nixosModules.kronii { inherit airi koyori osaka-greeter; }) ];
#   }
#
# which is what kronii actually builds. The settings themselves live next to
# the rest of the host config:
#
#   airi.nix     services.airi: Vivado install, hw_server, bench
#   koyori.nix   services.koyori: hub, cameras, detector, access
#   greeter.nix  services.osaka-greeter
{
  airi,
  koyori,
  osaka-greeter,
}:
{
  imports = [
    airi.nixosModules.default
    "${koyori}/nix/module.nix"
    "${osaka-greeter}/nix/module.nix"
    ./airi.nix
    ./koyori.nix
    ./greeter.nix
  ];
}

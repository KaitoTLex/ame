# osaka-greeter: the console login screen and status board on tty1 (greetd),
# for whoever plugs a monitor into the headless box. The option comes from
# osaka-greeter's own NixOS module, which unpublished.nix imports.
{ ... }:
{
  services.osaka-greeter.enable = true;
}

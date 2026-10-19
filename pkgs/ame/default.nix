{
  lib,
  writeShellApplication,
  coreutils,
  openssh,
  flake,
  hosts,
}:
writeShellApplication {
  name = "ame";
  # nix and nixos-rebuild come from the system on purpose, so they always
  # match the running nix-daemon.
  runtimeInputs = [
    coreutils
    openssh
  ];
  text = ''
    flake=${lib.escapeShellArg flake}
    hosts=(${lib.escapeShellArgs hosts})
  ''
  + builtins.readFile ./ame.sh;
}

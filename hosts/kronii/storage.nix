# btrfs subvolumes @, @home, @nix, @log on the "nixos" partition.
# hardware-configuration.nix mounts them by subvol=; these options add to that.
{ lib, ... }:
{
  fileSystems =
    lib.genAttrs
      [
        "/"
        "/home"
        "/nix"
        "/var/log"
      ]
      (_: {
        options = [
          "compress=zstd"
          "noatime"
        ];
      });

  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ]; # one scrub covers every subvolume
  };
}

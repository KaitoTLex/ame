# Secondary drives, formatted by ./setup-drives.sh (LUKS UUIDs must match).
# Unlocked in stage 2 with keyfiles kept on the encrypted root, so only the
# root passphrase is typed at boot.
{ ... }:
let
  btrfsOpts = [
    "compress=zstd"
    "noatime"
  ];
in
{
  environment.etc.crypttab.text = ''
    futaba UUID=e7f91d85-e456-47ab-8220-b0ecdc8b0873 /var/lib/luks-keys/futaba.key luks,discard
    data   UUID=5d15d0a4-bce7-4f4f-b0e0-c605aee0539e /var/lib/luks-keys/data.key   luks,discard,nofail
  '';

  # Crucial T710 1TB: futabatlex's home.
  fileSystems."/home/futabatlex" = {
    device = "/dev/mapper/futaba";
    fsType = "btrfs";
    options = [ "subvol=home" ] ++ btrfsOpts;
  };

  # T-FORCE 500GB: shared storage. nofail so a dead SATA drive doesn't block boot.
  fileSystems."/data" = {
    device = "/dev/mapper/data";
    fsType = "btrfs";
    options = [
      "subvol=data"
      "nofail"
    ]
    ++ btrfsOpts;
  };

  # The fresh btrfs roots are root-owned; fix ownership once mounted.
  # /data is setgid "users" so files from either account stay group-writable.
  systemd.tmpfiles.rules = [
    "d /home/futabatlex 0700 futabatlex users -"
    "d /data 2775 root users -"
  ];

  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [
      "/home/futabatlex"
      "/data"
    ];
  };
}

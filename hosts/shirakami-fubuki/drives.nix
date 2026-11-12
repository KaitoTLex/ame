# Secondary drives.
#
# The T-FORCE SATA SSD is LUKS2 + keyfile from ./setup-drives.sh, and its LUKS
# UUID must match the crypttab line below.
#
# The Crucial T710 is NOT encrypted. It carries futabatlex's live home (and the
# pre-wipe offload of kaitotlex's), so it is mounted by filesystem UUID
# directly instead of through /dev/mapper. setup-drives.sh's futaba leg would
# reformat it -- do not run it against this drive.
{ ... }:
let
  btrfsOpts = [
    "compress=zstd"
    "noatime"
  ];
in
{
  # data.key lived on the old root disk and went with it, so /data cannot
  # auto-unlock yet. nofail keeps that from blocking boot. To restore it, using
  # the backup passphrase setup-drives.sh added to the drive:
  #   install -d -m700 /var/lib/luks-keys
  #   (umask 077; head -c 4096 /dev/urandom >/var/lib/luks-keys/data.key)
  #   cryptsetup luksAddKey /dev/disk/by-uuid/5d15d0a4-bce7-4f4f-b0e0-c605aee0539e \
  #     /var/lib/luks-keys/data.key
  environment.etc.crypttab.text = ''
    data UUID=5d15d0a4-bce7-4f4f-b0e0-c605aee0539e /var/lib/luks-keys/data.key luks,discard,nofail
  '';

  # Crucial T710 1TB, plain btrfs (label "futaba"): futabatlex's home.
  fileSystems."/home/futabatlex" = {
    device = "/dev/disk/by-uuid/03c5a162-0042-41fe-808d-c792535c23d3";
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

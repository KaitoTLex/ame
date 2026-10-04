#!/usr/bin/env bash
# One-shot: wipe the Crucial T710 NVMe and the T-FORCE SATA SSD, then create
# GPT -> LUKS2 (keyfile) -> btrfs on each. drives.nix unlocks and mounts them.
# The LUKS UUIDs here must match drives.nix.
#
# Run as root from a real terminal: sudo bash hosts/shirakami-fubuki/setup-drives.sh
set -euo pipefail

KEYDIR=/var/lib/luks-keys

# name  by-id disk                                    luks uuid                             btrfs label  subvolume
DRIVES=(
  "futaba /dev/disk/by-id/nvme-CT1000T710SSD8_25395358225E e7f91d85-e456-47ab-8220-b0ecdc8b0873 futaba home"
  "data   /dev/disk/by-id/ata-T-FORCE_500GB_112102020160251 5d15d0a4-bce7-4f4f-b0e0-c605aee0539e data   data"
)

[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }

root_disk=$(lsblk -no PKNAME "$(findmnt -no SOURCE /boot)")
for d in "${DRIVES[@]}"; do
  read -r _ disk _ _ _ <<<"$d"
  dev=$(readlink -f "$disk")
  [[ -b $dev ]] || { echo "missing $disk" >&2; exit 1; }
  [[ $(basename "$dev") != "$root_disk" ]] || { echo "$disk is the boot disk, refusing" >&2; exit 1; }
  if lsblk -no MOUNTPOINTS "$dev" | grep -q .; then
    echo "$dev has mounted filesystems, refusing" >&2; exit 1
  fi
done

echo "About to DESTROY all data on:"
for d in "${DRIVES[@]}"; do
  read -r _ disk _ _ _ <<<"$d"
  lsblk -o NAME,SIZE,MODEL,FSTYPE "$(readlink -f "$disk")"
done
read -rp "Type WIPE to continue: " ans
[[ $ans == WIPE ]] || { echo "aborted"; exit 1; }

install -d -m 700 "$KEYDIR"

for d in "${DRIVES[@]}"; do
  read -r name disk uuid label subvol <<<"$d"
  key="$KEYDIR/$name.key"
  part="$disk-part1"
  echo "==> $name ($disk)"

  wipefs -a "$disk"
  echo 'label: gpt
type=linux' | sfdisk --quiet "$disk"
  udevadm settle
  [[ -b $part ]] || { echo "partition $part did not appear" >&2; exit 1; }

  [[ -e $key ]] || (umask 077; head -c 4096 /dev/urandom >"$key")
  cryptsetup luksFormat --batch-mode --type luks2 --uuid "$uuid" --key-file "$key" "$part"

  echo "Set a backup passphrase for $name (recovers the drive if the root disk dies):"
  cryptsetup luksAddKey --key-file "$key" "$part"

  cryptsetup open --key-file "$key" "$part" "$name"
  mkfs.btrfs -f -L "$label" "/dev/mapper/$name"
  mnt=$(mktemp -d)
  mount "/dev/mapper/$name" "$mnt"
  btrfs subvolume create "$mnt/$subvol"
  umount "$mnt"
  rmdir "$mnt"
  cryptsetup close "$name"
done

echo
echo "Done. Next: nh os switch . (from kaitotlex), then: sudo passwd futabatlex"

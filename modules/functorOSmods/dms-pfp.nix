{ pkgs, ... }:
{
  # DMS (Modules/Services/PortalService.qml) only ever reads the avatar over
  # D-Bus via freedesktop.accounts.getUserIconFile -- there is no settings.json
  # key for a static image path, so AccountsService is the only declarative
  # entry point. `C+` (copy, not symlink) is used so accounts-daemon can still
  # rewrite its own fields (Language, SystemAccount, ...) into the ini file
  # between activations without hitting a read-only nix-store symlink target;
  # every activation re-copies our pure, nix-store-derived content over it.
  services.accounts-daemon.enable = true;

  systemd.tmpfiles.rules = [
    "C+ /var/lib/AccountsService/icons/kaitotlex - - - - ${../../pfp.png}"
    "C+ /var/lib/AccountsService/users/kaitotlex - - - - ${pkgs.writeText "kaitotlex-accountsservice" ''
      [User]
      Icon=/var/lib/AccountsService/icons/kaitotlex
      SystemAccount=false
    ''}"
  ];
}

{ ... }:
{
  services.accounts-daemon.enable = true;

  systemd.tmpfiles.rules = [
    "L+ /var/lib/AccountsService/icons/kaitotlex - - - - ${../../pfp.png}"
    "f+= /var/lib/AccountsService/users/kaitotlex 0600 root root - [User]\\nIcon=/var/lib/AccountsService/icons/kaitotlex\\nSystemAccount=false\\n"
  ];
}

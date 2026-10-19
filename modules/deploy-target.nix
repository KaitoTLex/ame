# Lets shirakami-fubuki push builds here with `ame` (see pkgs/ame.nix).
#
# Activating a system needs root, and these hosts use run0 instead of sudo,
# which can't prompt over a non-interactive ssh session. So shirakami logs in
# as root directly, with its own key only. sshd already runs with
# PermitRootLogin = "prohibit-password", so passwords are never accepted.
# The from= restriction limits the key to the tailnet (100.64.0.0/10), so a
# stolen copy is useless from the open internet or the LAN.
{
  users.users.root.openssh.authorizedKeys.keys = [
    ''from="100.64.0.0/10" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGd1/dOHQnbqICZ6aAVu25IcZshlfGfXvXcvIJ8As4h5 kaitotlex@shirakami-fubuki''
  ];
}

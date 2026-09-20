let
  # kuroko = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICxFSaNa3iYaz98jvd+ggdnZSKy8GxpbrVI36C6gBSER kaitotlex@kuroko";
  # kuroko-root = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIxIOrmCqEKAxS6pMNB5qKkqtcM4IUQtxX/5Y3XhtWJZ root@kuroko";
  shirakami-fubuki = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID7JNmV6J/ttXTQvyx5/IsSK+E6FwXKTH3+7xNaJFpQc root@shirakami-fubuki";
  kanade = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFLwiBCboUAGMjoNnv1Cr9lO2QSm1/S68vx4VQvCDrKe root@kanade";
  # Pre-generated on kanade (~/.ssh/nanashi_host_ed25519_key); install the
  # private half as /etc/ssh/ssh_host_ed25519_key on nanashi.
  nanashi = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4poHv6dmBSi1zPSRNUbv4LLS6LhUldvq4BJBWEb/1/ root@nanashi";
in
{
  "eduroam.age".publicKeys = [
    shirakami-fubuki
    kanade
    nanashi
  ];

  "ghtoken.age".publicKeys = [
    shirakami-fubuki
    kanade
    nanashi
  ];
}

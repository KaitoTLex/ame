let
  # kuroko = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICxFSaNa3iYaz98jvd+ggdnZSKy8GxpbrVI36C6gBSER kaitotlex@kuroko";
  # kuroko-root = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIxIOrmCqEKAxS6pMNB5qKkqtcM4IUQtxX/5Y3XhtWJZ root@kuroko";
  shirakami-fubuki = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID7JNmV6J/ttXTQvyx5/IsSK+E6FwXKTH3+7xNaJFpQc root@shirakami-fubuki";
in
{
  "eduroam.age".publicKeys = [
    shirakami-fubuki
    # kuroko
    # kuroko-root
  ];
}

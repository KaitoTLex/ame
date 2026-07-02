let
  kuroko = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICxFSaNa3iYaz98jvd+ggdnZSKy8GxpbrVI36C6gBSER kaitotlex@kuroko";
  kuroko-root = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIxIOrmCqEKAxS6pMNB5qKkqtcM4IUQtxX/5Y3XhtWJZ root@kuroko";
in
{
  "eduroam.age".publicKeys = [
    shirakami-fubuki
    kuroko
    kuroko-root
  ];
}

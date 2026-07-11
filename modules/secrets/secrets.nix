let
  # kuroko = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICxFSaNa3iYaz98jvd+ggdnZSKy8GxpbrVI36C6gBSER kaitotlex@kuroko";
  # kuroko-root = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIxIOrmCqEKAxS6pMNB5qKkqtcM4IUQtxX/5Y3XhtWJZ root@kuroko";
  shirakami-fubuki = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID7JNmV6J/ttXTQvyx5/IsSK+E6FwXKTH3+7xNaJFpQc root@shirakami-fubuki";
  # kanade = ""
in
{
  "eduroam.age".publicKeys = [
    shirakami-fubuki
    # kanade
    # kuroko
    # kuroko-root
  ];

  # Nix `access-tokens` line (e.g. `access-tokens = github.com=ghp_xxx`) used
  # via `!include` so `nix` can authenticate fetches of the private flake.
  # kanade's host key isn't added yet -- add it here once available.
  "ghtoken.age".publicKeys = [
    shirakami-fubuki
    # kanade
  ];
}

# Who can log in. sshd itself (keys only) is set up in modules/server.nix;
# network.nix opens it on the LAN, and the tailnet is trusted.
{
  users.users.kaitotlex.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMkS6tVvx8qfgfWaP3W2MjWl8lYvu9NK75db9Fyn3oSR kaitotlex@nanashi"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHjmMf4qjTI2ltl6FVRAjbnIiOguyXfRQnTcNhde2coZ kaitotlex@chisa"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGd1/dOHQnbqICZ6aAVu25IcZshlfGfXvXcvIJ8As4h5 kaitotlex@shirakami-fubuki"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMwfHIQZRf1T89mkTnsCO24+q7B027UoolG1hgEYdQi4 lrcocobao@icloud.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClg0nwuttf6f601gNInczrafRkiknhSMfIB2ccsvGgx ren@boston"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH+c7TaA8LjC3bD4Zc38QBGdPthPx3y6yweEc8bqd8rf kaitotlex@kanade"
    # The shigure-ui hermes agent, so it can run jobs here.
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAx5PcDJ1T5pm4SUhpe03FuV6lPdJENcQt/dUIL/4KoD hermes-shigure-ui@shigure-ui"
  ];

  # run0 can't prompt over a non-interactive ssh session, so remote admin and
  # `nixos-rebuild --target-host` log in as root, with nanashi's key only and
  # only from the tailnet or the LAN (like deploy-target.nix, plus the LAN as
  # a way back in if tailscale is down). kaitotlex's password lives in
  # /etc/shadow (users are mutable); set it with `passwd`, run0 asks for it.
  users.users.root.openssh.authorizedKeys.keys = [
    ''from="100.64.0.0/10,192.168.1.0/24" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMkS6tVvx8qfgfWaP3W2MjWl8lYvu9NK75db9Fyn3oSR kaitotlex@nanashi''
  ];
}

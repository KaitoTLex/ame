# shirakami builds and deploys the whole fleet: `ame switch` builds every host
# here and pushes it out over tailscale (pkgs/ame, and modules/deploy-target.nix
# on the receiving end).
{
  pkgs,
  config,
  ...
}:
{
  environment.systemPackages = [
    (pkgs.callPackage ../../pkgs/ame {
      flake = config.functorOS.flakeLocation;
      hosts = [
        "shirakami-fubuki"
        "nanashi"
        "kanade"
      ];
    })
  ];

  # kanade is aarch64, so build it under qemu; most of it still comes from the
  # binary cache.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  # Scanned over tailscale, which already authenticates the peer. kanade isn't
  # pinned because it was offline at the time; ame trusts it on first contact.
  programs.ssh.knownHosts.nanashi = {
    hostNames = [
      "nanashi"
      "nanashi.tail7070c8.ts.net"
      "100.90.39.89"
    ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHe46Cikj0EbAbpOYFJmufQ2QcrOisZtbZL9q5gHmGJa";
  };
}

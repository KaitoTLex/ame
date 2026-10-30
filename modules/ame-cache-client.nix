# Trust shirakami-fubuki's harmonia binary cache.
#
# Imported by nanashi and kanade so `ame fetch` can substitute a generation
# instead of rebuilding it. shirakami itself does not import this: it is the
# machine serving the cache.
#
# The URL is the builder's tailscale IPv4, not a hostname: substitution must
# not depend on MagicDNS being up, and the cache is deliberately not exposed
# on the LAN (harmonia has no authentication of its own).
#
# TRUST MODEL: the private signing key lives only on shirakami as an agenix
# secret. The public half below is what makes a tampered or wrongly-signed
# path get *refused* rather than installed, so it is safe to have in git --
# but it must match the key actually in use, or every fetch fails with
# "signature is not valid".
{ lib, ... }:
let
  # Placeholder. Replace with the real value from, on shirakami:
  #   nix key convert-secret-to-public < /run/agenix/harmonia-signing-key
  # It looks like: ame-cache-1:<base64>=
  publicKey = "ame-cache-1:CfacrsQZEWXnd5q5Z0hk65weAMHsFivVeCFlPOXqcC0=";
in
{
  # Fail the build rather than deploying a cache config that can never
  # verify anything. Without this the placeholder would merely make every
  # `ame fetch` fail at runtime with a confusing signature error.
  assertions = [
    {
      assertion = !lib.hasInfix "REPLACE_ME" publicKey;
      message = ''
        modules/ame-cache-client.nix still has the placeholder signing key.

        On shirakami-fubuki, after the harmonia secret exists:
          nix key convert-secret-to-public < /run/agenix/harmonia-signing-key

        Put that value in `publicKey` in modules/ame-cache-client.nix.
      '';
    }
  ];

  nix.settings = {
    substituters = [ "http://100.103.1.34:5000" ];
    trusted-substituters = [ "http://100.103.1.34:5000" ];
    trusted-public-keys = [ publicKey ];
  };
}

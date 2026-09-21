# functorOS fetches functor-systems-icons from code.functor.systems, which sits
# behind Anubis. The bot challenge answers git's own user agent with HTML, so
# the fixed-output fetch fails on any machine that lacks the path in its store
# (fresh installs). ./identity is icons/ + LICENSE from identity.git @ 9a04adb,
# the rev functorOS pins. Only "${pkgs.functor-systems-icons}/icons/..." is ever
# interpolated, so a bare path stands in for the derivation.
# ponytail: pinned copy; use a git+ssh flake input if branding must track upstream.
{ lib, ... }:
{
  nixpkgs.overlays = lib.mkAfter [
    (_: _: { functor-systems-icons = ./identity; })
  ];
}

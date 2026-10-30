# Local fixes for functorOS at the pinned rev (aa7f6b4e, 2026-10-11) against
# nixpkgs after 2026-10-18, which dropped the scripted initrd (nixpkgs
# 316b009d). functorOS's stylix module still sets `boot.initrd.verbose` and
# `boot.initrd.systemd.enable`, both now hard assertions. Upstream HEAD
# (32256361) has the same lines, so unpinning does not help.
#
# This swaps functorOS's stylix module for a copy with those two lines
# removed. The copy is derived from the input at eval time, so it follows the
# pin. Remove this file once upstream drops the lines.
{ inputs }:
{ lib, ... }:
let
  src = "${inputs.functorOS}/modules/linux/stylix/default.nix";
  patched = builtins.toFile "functorOS-stylix-patched.nix" (
    builtins.replaceStrings
      [ "      initrd.verbose = false;\n" "      initrd.systemd.enable = true;\n" ]
      [ "" "" ]
      (builtins.readFile src)
  );
in
{
  disabledModules = [ "${inputs.functorOS}/modules/linux/stylix" src ];
  imports = [ patched ];
}

# The scroll session's monitor layout. The osaka-greeter status board used to run
# here in demo mode, fullscreen on the 1080p monitor (DP-1); it is switched off,
# so DP-1 is an ordinary output again. The login screen (greeter.nix) is separate.
inputs:
{
  lib,
  pkgs,
  ...
}:
{
  home-manager.users.kaitotlex = {
    wayland.windowManager.scroll.extraConfig = ''
      ${lib.concatMapStringsSep "\n" (n: "workspace number ${toString n} output DP-4") (lib.range 1 9)}
      exec ${lib.getExe pkgs.swayidle} -w timeout 600 'scrollmsg "output DP-4 power off"' resume 'scrollmsg "output DP-4 power on"'
    '';
  };
}

inputs:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  greeter = config.services.osaka-greeter.package;
  board = pkgs.writeShellScript "osaka-board" ''
    export PATH=/run/current-system/sw/bin:$PATH
    exec ${lib.getExe greeter} --demo
  '';
in
{
  home-manager.users.kaitotlex = {
    systemd.user.services.osaka-board = {
      Unit = {
        Description = "Status board on the 1080p monitor";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        ConditionEnvironment = "XDG_CURRENT_DESKTOP=scroll";
      };
      Service = {
        ExecStart = "${lib.getExe pkgs.foot} --app-id osaka-board -o font=monospace:size=10 ${board}";
        Restart = "always";
        RestartSec = 2;
      };
      Install.WantedBy = [ "scroll-session.target" ];
    };

    wayland.windowManager.scroll.extraConfig = ''
      workspace board output DP-1
      assign [app_id="osaka-board"] workspace board
      no_focus [app_id="osaka-board"]
      for_window [app_id="osaka-board"] fullscreen enable, border none
      ${lib.concatMapStringsSep "\n" (n: "workspace number ${toString n} output DP-4") (lib.range 1 9)}
      exec ${lib.getExe pkgs.swayidle} -w timeout 600 'scrollmsg "output DP-4 power off"' resume 'scrollmsg "output DP-4 power on"'
    '';
  };
}

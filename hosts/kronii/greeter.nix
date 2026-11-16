# osaka-greeter: the login screen and status board, on the 1080p monitor only.
# greetd runs a bare niri as the greeter user with the ultrawide (DP-4) switched
# off and the board fullscreen in foot on the VG249 (DP-1); a login starts
# niri-session and the user's niri lights both monitors (desktop.nix). If the
# board exits on its own the compositor quits too, so greetd brings it back.
# functorOS's ly is off (desktop.nix). The connector names change with the
# monitors' move to the 3050 (`niri msg outputs`).
#
# The options come from osaka-greeter's own NixOS module, which unpublished.nix
# imports.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  niri = config.programs.niri.package;
  # The board was drawn for 240x67 cells; a 10 pt monospace on 1920x1080 gives
  # about 240x63.
  board = pkgs.writeShellScript "osaka-greeter-board" ''
    "$OSAKA_GREETER"
    ${lib.getExe niri} msg action quit --skip-confirmation
  '';
  greeterConfig = pkgs.writeText "osaka-greeter-niri.kdl" ''
    output "DP-4" {
        off
    }
    output "DP-1" {
        mode "1920x1080"
    }
    hotkey-overlay {
        skip-at-startup
    }
    prefer-no-csd
    cursor {
        hide-after-inactive-ms 1000
    }
    layout {
        gaps 0
        focus-ring {
            off
        }
        border {
            off
        }
    }
    window-rule {
        open-fullscreen true
    }
    binds {
    }
    spawn-at-startup "${lib.getExe pkgs.foot}" "-F" "-o" "font=monospace:size=10" "${board}"
  '';
in
{
  services.osaka-greeter = {
    enable = true;
    greeterCommand = "${lib.getExe niri} -c ${greeterConfig}";
    session = [ "${niri}/bin/niri-session" ];
  };
}

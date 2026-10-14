# functorOS's niri binds on yabai. Karabiner (modules/home/karabiner.nix)
# makes the physical keys match kanade: option is Mod (left command here) and
# command is Ctrl (left control). Only left command is bound, so Ctrl
# shortcuts Karabiner sends as right command still reach apps.
{ config, pkgs, ... }:
let
  yabai = "yabai -m";
  jq = "${pkgs.jq}/bin/jq";

  # niri always keeps an empty workspace past the last one; create it on demand
  workspace = pkgs.writeShellScript "yabai-workspace" ''
    # usage: yabai-workspace focus|move prev|next
    action=$1 dir=$2
    if [ "$dir" = next ] && [ "$(${yabai} query --spaces --space | ${jq} '.index')" = \
         "$(${yabai} query --spaces --display | ${jq} 'map(.index) | max')" ]; then
      ${yabai} space --create
    fi
    if [ "$action" = move ]; then
      ${yabai} window --space "$dir"
    fi
    ${yabai} space --focus "$dir"
  '';

  # consume-or-expel-window-left/right: stacks act as niri columns
  consumeOrExpel = pkgs.writeShellScript "yabai-consume-or-expel" ''
    dir=$1
    win=$(${yabai} query --windows --window)
    if [ "$(echo "$win" | ${jq} '."stack-index"')" -gt 0 ]; then
      ${yabai} window --toggle float && ${yabai} window --toggle float
      ${yabai} window --warp "$dir"
    else
      ${yabai} window "$dir" --stack "$(echo "$win" | ${jq} '.id')"
    fi
  '';

  # switch-preset-column-width: 1/3 -> 1/2 -> 2/3
  presetWidth = pkgs.writeShellScript "yabai-preset-width" ''
    state="''${TMPDIR:-/tmp}/yabai-ratio-$(${yabai} query --windows --window | ${jq} '.id')"
    case "$(cat "$state" 2>/dev/null)" in
      0.33) next=0.5 ;;
      0.5) next=0.67 ;;
      *) next=0.33 ;;
    esac
    ${yabai} window --ratio "abs:$next" && echo "$next" > "$state"
  '';

  # dms power menu
  powermenu = pkgs.writeShellScript "powermenu" ''
    choice=$(osascript -e 'choose from list {"Lock", "Sleep", "Log Out", "Restart", "Shut Down"} with title "Power"')
    case "$choice" in
      Lock) pmset displaysleepnow ;;
      Sleep) pmset sleepnow ;;
      "Log Out") osascript -e 'tell application "System Events" to log out' ;;
      Restart) osascript -e 'tell application "System Events" to restart' ;;
      "Shut Down") osascript -e 'tell application "System Events" to shut down' ;;
    esac
  '';

  # grim/slurp | swappy: capture, then annotate in Preview
  screenshot = pkgs.writeShellScript "screenshot" ''
    dir="$HOME/Pictures/Screenshots"
    mkdir -p "$dir"
    screencapture "$@" -P "$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
  '';
in
{
  # skhd doesn't notice /etc/skhdrc being relinked; restart it on switch
  system.activationScripts.postActivation.text = ''
    launchctl kickstart -k "gui/$(id -u ${config.system.primaryUser})/org.nixos.skhd" || true
  '';

  services.skhd = {
    enable = true;
    skhdConfig = ''
      lcmd - d : open -a "Mission Control"
      lcmd - backspace : ${powermenu}

      lcmd - h : ${yabai} window --focus west
      lcmd - j : ${yabai} window --focus stack.next || ${yabai} window --focus south
      lcmd - k : ${yabai} window --focus stack.prev || ${yabai} window --focus north
      lcmd - l : ${yabai} window --focus east

      lcmd + shift - h : ${yabai} window --swap west
      lcmd + shift - j : ${yabai} window --swap south
      lcmd + shift - k : ${yabai} window --swap north
      lcmd + shift - l : ${yabai} window --swap east

      lcmd + lctrl - h : ${yabai} display --focus west
      lcmd + lctrl - j : ${yabai} display --focus south
      lcmd + lctrl - k : ${yabai} display --focus north
      lcmd + lctrl - l : ${yabai} display --focus east

      lcmd - i : ${workspace} focus prev
      lcmd - u : ${workspace} focus next
      lcmd + shift - i : ${workspace} move prev
      lcmd + shift - u : ${workspace} move next
      lcmd + lctrl - i : ${yabai} space --move prev
      lcmd + lctrl - u : ${yabai} space --move next

      lcmd + shift + lctrl - h : ${yabai} window --display west && ${yabai} display --focus west
      lcmd + shift + lctrl - j : ${yabai} window --display south && ${yabai} display --focus south
      lcmd + shift + lctrl - k : ${yabai} window --display north && ${yabai} display --focus north
      lcmd + shift + lctrl - l : ${yabai} window --display east && ${yabai} display --focus east

      lcmd - r : open "x-apple.systempreferences:com.apple.Sound-Settings.extension"

      # comma, period, slash, semicolon, apostrophe
      lcmd - 0x2B : ${consumeOrExpel} west
      lcmd - 0x2F : ${consumeOrExpel} east
      lcmd - 0x2C : ${yabai} window --toggle float && ${yabai} window --toggle float
      lcmd - 0x29 : ${presetWidth}
      lcmd - 0x27 : ${yabai} window --toggle split

      lcmd - c : ${yabai} space --balance
      lcmd + lctrl - c : ${yabai} window --toggle float && ${yabai} window --grid 6:6:1:1:4:4

      lcmd - return : ${yabai} window --toggle native-fullscreen
      lcmd - f : ${yabai} window --toggle zoom-fullscreen
      lcmd + shift - f : ${yabai} window --toggle windowed-fullscreen

      lcmd - p : ${screenshot} -i
      lcmd + shift - p : ${screenshot}

      lcmd - t : ${pkgs.kitty}/bin/kitty --single-instance --directory "$HOME"
      lcmd - b : /Applications/Zen.app/Contents/MacOS/zen --new-window
      lcmd - m : open -a Thunderbird
      lcmd - e : open "$HOME"

      lcmd - q : ${yabai} window --close
    '';
  };
}

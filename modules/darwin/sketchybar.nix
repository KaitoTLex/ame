# Stand-in for functorOS's dms bar (hm/modules/linux/desktop-environment/dms-shell):
# launcher, occupied workspaces and focused window on the left;
# music, caffeine, battery, control center and clock on the right, each in its
# own pill like the dms widgets. Coloured from stylix. The macOS menu bar is
# hidden, so the pills open its Control Center menus when clicked.
{ config, pkgs, ... }:
let
  c = config.lib.stylix.colors;
  argb = hex: "0xff${hex}";
  icons = config.stylix.fonts.monospace.name;
  text = config.stylix.fonts.sansSerif.name;

  yabai = "yabai -m";
  jq = "${pkgs.jq}/bin/jq";
  # homebrew formula; the nixpkgs now-playing tools broke with macOS 15.4
  mediaControl = "/opt/homebrew/bin/media-control";

  # clicks a menu bar extra by identifier (its name is localised), e.g.
  # com.apple.menuextra.wifi; needs Accessibility access for sketchybar
  menuExtra = pkgs.writeText "menu-extra.applescript" ''
    on run argv
      tell application "System Events" to tell process "ControlCenter"
        repeat with extra in menu bar items of menu bar 1
          try
            if value of attribute "AXIdentifier" of extra is item 1 of argv then
              click extra
              return
            end if
          end try
        end repeat
      end tell
    end run
  '';
  openMenu = id: "osascript ${menuExtra} com.apple.menuextra.${id}";

  # dms showOccupiedWorkspacesOnly: hide empty spaces, keep the focused one.
  # no index, like dms: the focused space is a wide pill, occupied ones are dots
  spaces = pkgs.writeShellScript "sketchybar-spaces" ''
    while read -r index focused windows; do
      if [ "$focused" = true ]; then
        args+=(--set space.$index drawing=on icon.width=22 background.color=${argb c.base0D})
      elif [ "$windows" -gt 0 ]; then
        args+=(--set space.$index drawing=on icon.width=8 background.color=${argb c.base03})
      else
        args+=(--set space.$index drawing=off)
      fi
    done < <(${yabai} query --spaces | ${jq} -r '.[] | "\(.index) \(."has-focus") \(.windows | length)"')
    # spaces past the last one that exists
    count=$(${yabai} query --spaces | ${jq} length)
    for i in $(seq $((count + 1)) 10); do args+=(--set space.$i drawing=off); done
    sketchybar "''${args[@]}"
  '';
  focusedWindow = pkgs.writeShellScript "sketchybar-focused-window" ''
    win=$(${yabai} query --windows --window 2>/dev/null)
    app=$(echo "$win" | ${jq} -r '.app // empty')
    title=$(echo "$win" | ${jq} -r '.title // empty')
    if [ -z "$app" ]; then
      sketchybar --set "$NAME" drawing=off
    elif [ -z "$title" ] || [ "$title" = "$app" ]; then
      sketchybar --set "$NAME" drawing=on icon="$app" label.drawing=off
    else
      sketchybar --set "$NAME" drawing=on icon="$app" label="$title" label.drawing=on
    fi
  '';
  # sleep inhibitor: click toggles a caffeinate that keeps the display and system awake
  caffeine = pkgs.writeShellScript "sketchybar-caffeine" ''
    pidfile="''${TMPDIR:-/tmp}/sketchybar-caffeine.pid"
    running() { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }
    if [ "$SENDER" = mouse.clicked ]; then
      if running; then
        kill "$(cat "$pidfile")"
        rm -f "$pidfile"
      else
        caffeinate -di >/dev/null 2>&1 &
        echo $! > "$pidfile"
      fi
    fi
    if running; then
      sketchybar --set "$NAME" icon=󰅶 icon.color=${argb c.base0A}
    else
      sketchybar --set "$NAME" icon=󰛊 icon.color=${argb c.base04}
    fi
  '';
  clock = pkgs.writeShellScript "sketchybar-clock" ''
    sketchybar --set "$NAME" label="$(date '+%H:%M')"
  '';
  music = pkgs.writeShellScript "sketchybar-music" ''
    [ -x ${mediaControl} ] || { sketchybar --set "$NAME" drawing=off; exit 0; }
    info=$(${mediaControl} get 2>/dev/null)
    title=$(echo "$info" | ${jq} -r '.title // empty')
    if [ -z "$title" ]; then
      sketchybar --set "$NAME" drawing=off
      exit 0
    fi
    artist=$(echo "$info" | ${jq} -r '.artist // empty')
    if [ "$(echo "$info" | ${jq} -r '.playing')" = true ]; then icon=󰏤; else icon=󰐊; fi
    sketchybar --set "$NAME" drawing=on icon="$icon" label="$title''${artist:+ · $artist}"
  '';
  battery = pkgs.writeShellScript "sketchybar-battery" ''
    info=$(pmset -g batt)
    pct=$(echo "$info" | grep -Eo '[0-9]+%' | tr -d %)
    [ -z "$pct" ] && { sketchybar --set "$NAME" drawing=off; exit 0; }
    color=${argb c.base05}
    if echo "$info" | grep -q 'AC Power'; then icon=󰂄
    elif [ "$pct" -ge 90 ]; then icon=󰁹
    elif [ "$pct" -ge 70 ]; then icon=󰂁
    elif [ "$pct" -ge 50 ]; then icon=󰁾
    elif [ "$pct" -ge 30 ]; then icon=󰁼
    elif [ "$pct" -ge 15 ]; then icon=󰁺
    else icon=󰂃 color=${argb c.base08}
    fi
    sketchybar --set "$NAME" icon="$icon" icon.color="$color" label="$pct%"
  '';
  # left click plays/pauses, right click opens the Now Playing menu
  musicClick = pkgs.writeShellScript "sketchybar-music-click" ''
    if [ "$BUTTON" = right ]; then
      ${openMenu "now-playing"}
    else
      ${mediaControl} toggle-play-pause
    fi
  '';
  # dms control center button shows network and audio state; here each icon
  # is its own item so it can open the matching macOS menu
  network = pkgs.writeShellScript "sketchybar-network" ''
    if ipconfig getsummary en0 2>/dev/null | grep -q ' SSID'; then icon=󰖩; else icon=󰖪; fi
    sketchybar --set "$NAME" icon="$icon"
  '';
  sound = pkgs.writeShellScript "sketchybar-sound" ''
    vol=$(osascript -e 'output volume of (get volume settings)')
    muted=$(osascript -e 'output muted of (get volume settings)')
    if [ "$muted" = true ] || [ "$vol" = 0 ]; then icon=󰝟
    elif [ "$vol" -lt 50 ]; then icon=󰖀
    else icon=󰕾
    fi
    sketchybar --set "$NAME" icon="$icon"
  '';
in
{
  services.sketchybar = {
    enable = true;
    extraPackages = [ pkgs.jq ];
    config = ''
      #!/bin/bash
      sketchybar --bar position=top height=36 margin=8 y_offset=6 corner_radius=12 \
        color=${argb c.base00} border_width=0 shadow=on padding_left=4 padding_right=4

      # every widget is a pill, as in dms (spacing 4, innerPadding 4)
      sketchybar --default \
        icon.font="${icons}:Bold:15.0" label.font="${text}:Medium:13.0" \
        icon.color=${argb c.base05} label.color=${argb c.base05} \
        padding_left=2 padding_right=2 \
        icon.padding_left=10 icon.padding_right=6 label.padding_left=0 label.padding_right=10 \
        background.color=${argb c.base01} background.corner_radius=9 background.height=28

      sketchybar --add event window_focus --add event title_change --add event space_change

      # launcherButton
      sketchybar --add item launcher left \
        --set launcher icon=󰀵 icon.color=${argb c.base0D} icon.font="${icons}:Regular:18.0" \
          icon.padding_right=10 label.drawing=off click_script="open -a Apps"

      # workspaceSwitcher
      for i in $(seq 1 10); do
        sketchybar --add item space.$i left \
          --set space.$i icon=" " icon.width=8 icon.padding_left=0 icon.padding_right=0 \
            label.drawing=off drawing=off padding_left=3 padding_right=3 \
            background.color=${argb c.base03} background.corner_radius=4 background.height=8 \
            click_script="${yabai} space --focus $i"
      done
      sketchybar --add bracket spaces '/space\..*/' \
        --set spaces background.color=${argb c.base01} background.corner_radius=9 background.height=28
      sketchybar --add item spaces_update left \
        --set spaces_update drawing=off updates=on script="${spaces}" \
        --subscribe spaces_update space_change space_windows_change window_focus display_change

      # focusedWindow
      sketchybar --add item focused_window left \
        --set focused_window icon.font="${text}:Bold:13.0" icon.color=${argb c.base0D} \
          label.max_chars=48 script="${focusedWindow}" \
        --subscribe focused_window window_focus front_app_switched title_change space_change

      # right side, outermost first
      # the clock opens Notification Center, as on the macOS menu bar
      sketchybar --add item clock right \
        --set clock icon=󰥔 update_freq=15 script="${clock}" click_script="${openMenu "clock"}"

      # controlCenterButton: one pill of icons, each opening its own menu
      cc_item="label.drawing=off icon.padding_left=5 icon.padding_right=5 padding_left=0 padding_right=0 background.drawing=off"
      sketchybar --add item cc.control_center right \
        --set cc.control_center $cc_item icon=󰒓 icon.padding_right=10 \
          click_script="${openMenu "controlcenter"}" \
        --add item cc.bluetooth right \
        --set cc.bluetooth $cc_item icon=󰂯 click_script="${openMenu "bluetooth"}" \
        --add item cc.sound right \
        --set cc.sound $cc_item script="${sound}" click_script="${openMenu "sound"}" \
        --subscribe cc.sound volume_change system_woke \
        --add item cc.network right \
        --set cc.network $cc_item icon.padding_left=10 update_freq=30 script="${network}" \
          click_script="${openMenu "wifi"}" \
        --subscribe cc.network wifi_change system_woke
      sketchybar --add bracket control_center '/cc\..*/' \
        --set control_center background.color=${argb c.base01} background.corner_radius=9 background.height=28

      sketchybar --add item battery right \
        --set battery update_freq=120 script="${battery}" click_script="${openMenu "battery"}" \
        --subscribe battery power_source_change system_woke

      sketchybar --add item caffeine right \
        --set caffeine label.drawing=off icon.padding_right=10 script="${caffeine}" \
        --subscribe caffeine mouse.clicked

      sketchybar --add item music right \
        --set music drawing=off icon.color=${argb c.base0B} label.max_chars=36 \
          update_freq=5 script="${music}" click_script="${musicClick}"

      sketchybar --update
    '';
  };
}

# yabai standing in for niri; values follow functorOS's niri layout.
{ ... }:
{
  services.yabai = {
    enable = true;
    # needs SIP partially disabled; without it the space binds don't work
    enableScriptingAddition = true;
    config = {
      layout = "bsp";
      # new windows open to the right of / below the focused one, like a new niri column
      window_placement = "second_child";
      split_ratio = 0.5;
      auto_balance = "off";

      # niri layout.gaps = 8
      top_padding = 8;
      bottom_padding = 8;
      left_padding = 8;
      right_padding = 8;
      window_gap = 8;
      # room for sketchybar
      external_bar = "all:42:0";

      # niri window-rule opacity 0.95
      window_opacity = "on";
      active_window_opacity = 1.0;
      normal_window_opacity = 0.95;
      window_shadow = "on";
      window_animation_duration = 0.0;

      focus_follows_mouse = "off";
      mouse_follows_focus = "off";
      # Mod+drag moves, Mod+right-drag resizes
      mouse_modifier = "cmd";
      mouse_action1 = "move";
      mouse_action2 = "resize";
      mouse_drop_action = "swap";
    };
    extraConfig = ''
      yabai -m rule --add app="^System Settings$" manage=off
      yabai -m rule --add app="^System Information$" manage=off
      yabai -m rule --add app="^Calculator$" manage=off
      yabai -m rule --add app="^Archive Utility$" manage=off
      yabai -m rule --add app="^AltTab$" manage=off
      yabai -m rule --add app="^pinentry-mac$" manage=off
      yabai -m rule --add app="^Finder$" title="(Copy|Move|Info|Connect|Delete)" manage=off
      yabai -m rule --add title="(Preferences|Settings)$" manage=off

      # keep sketchybar's space and front-app items current
      yabai -m signal --add event=space_changed action="sketchybar --trigger space_change"
      yabai -m signal --add event=window_focused action="sketchybar --trigger window_focus"
      yabai -m signal --add event=application_front_switched action="sketchybar --trigger window_focus"
      yabai -m signal --add event=window_title_changed action="sketchybar --trigger title_change"
      yabai -m signal --add event=window_created action="sketchybar --trigger space_windows_change"
      yabai -m signal --add event=window_destroyed action="sketchybar --trigger space_windows_change"
    '';
  };

  # niri's focus ring; colours come from stylix's jankyborders target
  services.jankyborders = {
    enable = true;
    width = 4.0;
    hidpi = true;
    style = "round";
  };
}

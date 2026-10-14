# macOS settings; the keyboard part mirrors kanade's keyd remap.
{ pkgs, ... }:
let
  # HID usage page 7 (keyboard) codes, see Apple TN2450
  hid = code: 30064771072 + code;
  map' = src: dst: {
    HIDKeyboardModifierMappingSrc = hid src;
    HIDKeyboardModifierMappingDst = hid dst;
  };

  # Same base layer as modules/home/karabiner.nix, for when Karabiner isn't
  # running. Karabiner reads the built-in keyboard raw, before these apply, so
  # scoping them to it keeps the two from stacking.
  keymap = pkgs.writeShellScript "keymap" ''
    # clear the unscoped mapping older generations set
    /usr/bin/hidutil property --set '{"UserKeyMapping":[]}' >/dev/null
    /usr/bin/hidutil property --matching '{"Product":"Apple Internal Keyboard / Trackpad"}' --set '${
      builtins.toJSON {
        UserKeyMapping = [
          (map' 224 226) # ctrl -> option (Alt)
          (map' 226 227) # option -> command (Meta)
          (map' 227 224) # command -> control (Ctrl)
          (map' 231 226) # right command -> option
          (map' 57 41) # caps lock -> escape
          (map' 28 29) # y -> z
          (map' 29 28) # z -> y
        ];
      }
    }' >/dev/null
  '';
in
{
  system.activationScripts.postActivation.text = "${keymap}";
  # hidutil mappings only last until reboot; reapply them at login
  launchd.user.agents.keymap.serviceConfig = {
    ProgramArguments = [ "${keymap}" ];
    RunAtLoad = true;
  };

  system.defaults = {
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      ApplePressAndHoldEnabled = false;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticWindowAnimationsEnabled = false;
      NSWindowShouldDragOnGesture = true;
      _HIHideMenuBar = true;
    };
    dock = {
      autohide = true;
      mru-spaces = false;
      show-recents = false;
      tilesize = 40;
      expose-group-apps = true;
    };
    spaces.spans-displays = false;
    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "Nlsv";
      ShowPathbar = true;
      _FXShowPosixPathInTitle = true;
    };
    # niri has tap-to-click off
    trackpad.Clicking = false;
    screencapture.location = "~/Pictures/Screenshots";
    # in the menu bar (hidden) so the sketchybar pills can click them open
    controlcenter = {
      Sound = true;
      Bluetooth = true;
      NowPlaying = true;
    };
    CustomUserPreferences = {
      # same physical keys as niri/fcitx: Spotlight on Mod+space (physical
      # option, command under Karabiner), input source on Ctrl+space
      # (physical cmd), Finder search on Mod+Ctrl+space
      "com.apple.symbolichotkeys".AppleSymbolicHotKeys = {
        "60" = {
          enabled = true;
          value = {
            parameters = [ 32 49 262144 ];
            type = "standard";
          };
        };
        "64" = {
          enabled = true;
          value = {
            parameters = [ 32 49 1048576 ];
            type = "standard";
          };
        };
        "65" = {
          enabled = true;
          value = {
            parameters = [ 32 49 1310720 ];
            type = "standard";
          };
        };
      };
    };
  };
}

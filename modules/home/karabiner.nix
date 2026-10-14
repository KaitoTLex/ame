# kanade's keyd remap for Karabiner-Elements (cask in modules/darwin/homebrew.nix;
# modules/darwin/defaults.nix sets the same base layer with hidutil as a fallback):
# physical ctrl -> Alt (option), option -> Meta (command, the OS key skhd uses
# as Mod), command -> Ctrl (control). Outside terminals, Ctrl shortcuts are
# then sent as right command so copy/paste/etc. sit where they do on Linux;
# skhd only binds left command, so they reach the app.
{ lib, ... }:
let
  key = from: to: {
    from.key_code = from;
    to = [ { key_code = to; } ];
  };

  terminals = [
    "^net\\.kovidgoyal\\.kitty$"
    "^com\\.apple\\.Terminal$"
  ];
  outsideTerminals = [
    {
      type = "frontmost_application_unless";
      bundle_identifiers = terminals;
    }
  ];

  # ctrl+key -> cmd+key. h and m stay Ctrl: cmd+h/cmd+m would hide/minimize
  ctrlAsCmd =
    k:
    {
      type = "basic";
      from = {
        key_code = k;
        modifiers = {
          mandatory = [ "control" ];
          optional = [ "shift" ];
        };
      };
      to = [
        {
          key_code = k;
          modifiers = [ "right_command" ];
        }
      ];
      conditions = outsideTerminals;
    };
  shortcutKeys =
    lib.filter (k: k != "h" && k != "m") (lib.stringToCharacters "abcdefghijklmnopqrstuvwxyz")
    ++ lib.stringToCharacters "1234567890"
    ++ [
      "equal_sign"
      "hyphen"
      "slash"
      "comma"
    ];

  # ctrl+arrows/backspace move and delete by word, which is option on macOS
  ctrlAsOption = from: to: {
    type = "basic";
    from = {
      key_code = from;
      modifiers = {
        mandatory = [ "control" ];
        optional = [ "shift" ];
      };
    };
    to = [
      {
        key_code = to;
        modifiers = [ "left_option" ];
      }
    ];
    conditions = outsideTerminals;
  };

  config = {
    global.show_in_menu_bar = false;
    profiles = [
      {
        name = "kanade";
        selected = true;
        virtual_hid_keyboard.keyboard_type_v2 = "ansi";
        simple_modifications = [
          (key "left_control" "left_option")
          (key "left_option" "left_command")
          (key "left_command" "left_control")
          (key "right_command" "left_option")
          (key "caps_lock" "escape")
          (key "y" "z")
          (key "z" "y")
        ];
        complex_modifications.rules = [
          {
            description = "Linux Ctrl shortcuts outside terminals";
            manipulators =
              map ctrlAsCmd shortcutKeys
              ++ [
                (ctrlAsOption "left_arrow" "left_arrow")
                (ctrlAsOption "right_arrow" "right_arrow")
                (ctrlAsOption "delete_or_backspace" "delete_or_backspace")
                (ctrlAsOption "delete_forward" "delete_forward")
              ];
          }
        ];
      }
    ];
  };
in
{
  # read-only symlink: change it here, not in the Karabiner settings UI
  xdg.configFile."karabiner/karabiner.json".text = builtins.toJSON config;
}

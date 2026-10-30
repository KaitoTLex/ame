# scroll (sway fork, scrolling layout) next to functorOS's niri.
#
# functorOS ships niri + dank-material-shell (DMS) with a fixed keymap. This
# module adds scroll as a second session, riced the same way: same DMS, same
# keymap, same monitors. Nothing in functorOS is modified and niri stays
# installed, so the greeter (ly) offers both.
#
# One module, two halves: `nixos` (system) and `home` (home-manager). The
# flake wires both. Enable with `functorOS.desktop.scroll.enable = true` at
# the system level; the home half follows it through osConfig.
#
# Keymap: identical chords to functorOS's niri binds (hm/modules/linux/
# desktop-environment/niri/default.nix at the pinned rev). Actions scroll has
# no command for are in scroll-niri.sh. Monitors and the touchpad are read from
# programs.niri.settings, so a host only declares them once.
#
# Gaps: zero. `gaps inner 0`, `gaps outer 0`, `smart_gaps off`, no borders,
# no rounded corners. DMS's bar sits in the layer shell with no spacing or
# popup gap, see functorOSmods/caffeine.nix.
{ inputs }:
{
  nixos =
    { config, lib, pkgs, ... }:
    let
      cfg = config.functorOS.desktop.scroll;
    in
    {
      imports = [ inputs.scroll-flake.nixosModules.default ];

      options.functorOS.desktop.scroll = {
        enable = lib.mkEnableOption "scroll as a second functorOS compositor, next to niri";
        package = lib.mkOption {
          type = lib.types.package;
          default = inputs.scroll-flake.packages.${pkgs.stdenv.hostPlatform.system}.scroll-stable;
          description = "scroll package. scroll-git for master.";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.scroll = {
          enable = true;
          package = cfg.package;
          wrapperFeatures.gtk = true;
          # functorOS's niri path uses xwayland-satellite; scroll has built-in Xwayland.
          xwayland.enable = true;
          extraSessionCommands = ''
            export XDG_CURRENT_DESKTOP=scroll
            export XDG_SESSION_DESKTOP=scroll
            export QT_QPA_PLATFORM=wayland
            export QT_QPA_PLATFORMTHEME=qt5ct
            export ELECTRON_OZONE_PLATFORM_HINT=auto
            export NIXOS_OZONE_WL=1
          '';
          # The flake's default list pulls in swaylock/swayidle/wmenu/kitty; DMS
          # replaces the first three and functorOS already installs kitty.
          extraPackages = with pkgs; [
            grim
            slurp
            swappy
            brightnessctl
            xdg-desktop-portal
            xdg-desktop-portal-gtk
            xdg-desktop-portal-wlr
          ];
        };

        # DMS needs these two for the lock screen and interface scaling; wlr
        # portal gives screenshare on sway-family compositors.
        xdg.portal.enable = true;
        xdg.portal.wlr.enable = true;

        # functorOS's greeter lists sessions from displayManager.sessionPackages.
        # programs.scroll and programs.niri each add their own .desktop there.
      };
    };

  home =
    { config, lib, pkgs, osConfig, ... }:
    let
      cfg = config.functorOS.desktop.scroll;
      c = config.lib.stylix.colors.withHashtag;
      dms = lib.getExe config.programs.dank-material-shell.package;
      ipc = args: "exec ${dms} ipc call ${args}";
      mod = "Mod4";
      niri = config.programs.niri.settings;
      onOff = enabled: if enabled then "enabled" else "disabled";

      scroll-niri = pkgs.writeShellApplication {
        name = "scroll-niri";
        runtimeInputs = [
          osConfig.functorOS.desktop.scroll.package
          pkgs.jq
          pkgs.gawk
        ];
        text = builtins.readFile ./scroll-niri.sh;
      };
      helper = args: "exec ${lib.getExe scroll-niri} ${args}";

      # niri and sway both name a monitor "make model serial" or by connector,
      # so the host's niri outputs carry straight over.
      outputs = lib.filterAttrs (_: o: o.enable) niri.outputs;
      toScrollOutput =
        o:
        lib.optionalAttrs (o.mode != null) {
          mode =
            "${toString o.mode.width}x${toString o.mode.height}"
            + lib.optionalString (o.mode.refresh != null) "@${toString o.mode.refresh}Hz";
        }
        // lib.optionalAttrs (o.position != null) {
          position = "${toString o.position.x} ${toString o.position.y}";
        }
        // lib.optionalAttrs (o.scale != null) { scale = toString o.scale; }
        // lib.optionalAttrs (o.transform.rotation != 0 || o.transform.flipped) {
          transform =
            if o.transform.rotation == 0 then
              "flipped"
            else
              lib.optionalString o.transform.flipped "flipped-" + toString o.transform.rotation;
        }
        // lib.optionalAttrs (o.variable-refresh-rate != false) { adaptive_sync = "on"; };
      startupOutput = lib.findFirst (name: outputs.${name}.focus-at-startup) null (
        lib.attrNames outputs
      );

      touchpad = niri.input.touchpad;
    in
    {
      imports = [ inputs.scroll-flake.homeModules.default ];

      options.functorOS.desktop.scroll.enable = lib.mkOption {
        type = lib.types.bool;
        default = osConfig.functorOS.desktop.scroll.enable or false;
        description = "Rice scroll with the functorOS keymap and DMS.";
      };

      config = lib.mkIf cfg.enable {
        # dms-shell follows osConfig...niri.enable; keep it on if a host ever
        # runs scroll alone. Its bar settings are the same in both sessions.
        functorOS.desktop.dms-shell.enable = lib.mkForce true;

        # DMS's systemd unit binds to graphical-session.target, which
        # scroll-session.target pulls in.
        home.packages = with pkgs; [
          wl-clipboard
          wl-kbptr
          playerctl
          pavucontrol
          grim
          slurp
          swappy
        ];

        wayland.windowManager.scroll = {
          enable = true;
          package = null; # system-wide from programs.scroll
          systemd = {
            enable = true;
            # niri-session hands the whole login environment to systemd; do the same.
            variables = [ "--all" ];
            # scroll-flake's default waits on `scroll -mt subscribe`, but scroll
            # itself has no -m: it exits straight away and takes the session
            # target, and DMS with it, down at login. The unset is for linger:
            # the user manager outlives the session and niri may be next.
            extraCommands = [
              "systemctl --user reset-failed"
              "systemctl --user start scroll-session.target"
              "scrollmsg -mt subscribe '[]' || true"
              "systemctl --user stop scroll-session.target"
              "systemctl --user unset-environment WAYLAND_DISPLAY DISPLAY I3SOCK SWAYSOCK SCROLLSOCK XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP"
            ];
          };
          checkConfig = false; # the sway checker does not know scroll commands
          config = {
            modifier = mod;
            terminal = lib.getExe pkgs.kitty;
            menu = "${dms} ipc call spotlight toggle";

            # ---- gapless ----
            gaps = {
              inner = 0;
              outer = 0;
            };
            window = {
              border = 0;
              titlebar = false;
              hideEdgeBorders = "both";
              borderRadius = 0;
              titlebarBorderRadius = 0;
              # niri's shadow, softness 30 / spread 5 / offset 0 5.
              shadow = {
                enable = true;
                size = 5;
                blur = 30;
                offset = [ 0 5 ];
                color = if osConfig.stylix.polarity == "light" then "#00000070" else "#12121270";
              };
              # niri's focus ring is drawn in the gaps, and there aren't any.
              dim = {
                enable = true;
                color = "#00000030";
              };
            };
            floating = {
              border = 0;
              titlebar = false;
            };
            # DMS draws the bar in the layer shell; no swaybar.
            bars = [ ];

            fonts = {
              names = [ config.stylix.fonts.monospace.name ];
              size = config.stylix.fonts.sizes.desktop * 1.0;
            };

            # Focus ring in the two stylix accents, same as the niri gradient.
            # scroll has no gradient; active uses base0A, inactive invisible.
            colors = {
              focused = { border = c.base0A; background = c.base00; text = c.base05; indicator = c.base09; childBorder = c.base0A; };
              focusedInactive = { border = c.base00; background = c.base00; text = c.base04; indicator = c.base00; childBorder = c.base00; };
              unfocused = { border = c.base00; background = c.base00; text = c.base03; indicator = c.base00; childBorder = c.base00; };
              urgent = { border = c.base08; background = c.base00; text = c.base05; indicator = c.base08; childBorder = c.base08; };
            };

            output = lib.mapAttrs (_: toScrollOutput) outputs;

            input."type:touchpad" = {
              tap = onOff touchpad.tap;
              natural_scroll = onOff touchpad.natural-scroll;
              dwt = onOff touchpad.dwt;
            }
            // lib.optionalAttrs (touchpad.click-method != null) {
              click_method = lib.replaceStrings [ "-" ] [ "_" ] touchpad.click-method;
            }
            // lib.optionalAttrs (touchpad.tap-button-map != null) {
              tap_button_map = if touchpad.tap-button-map == "left-right-middle" then "lrm" else "lmr";
            };

            seat."*" = {
              xcursor_theme = "${config.stylix.cursor.name} ${toString config.stylix.cursor.size}";
              hide_cursor = "when-typing enable";
            };

            focus.followMouse = "yes";
            workspaceAutoBackAndForth = false;

            # niri reduceMotion = true: short, no overshoot. The module's
            # defaults are 300-500 ms with a spring on window_move; flatten them.
            animations =
              let
                fast = { enable = true; duration = 150; var = { order = 3; controlPoints = [ 0.215 0.61 0.355 1 ]; }; };
              in
              {
                enable = true;
                style = "clip";
                default = fast;
                windowOpen = fast;
                windowMove = fast // { off = { scale = null; order = null; controlPoints = null; }; };
                windowSize = fast;
                workspaceSwitch = fast // { duration = 200; };
                windowFullscreen = fast;
                jump = fast;
                layerShell = fast;
                fadeIn = fast;
                fadeOut = fast;
              };

            # ---- the functorOS keymap, translated ----
            # niri -> scroll, chord for chord. Plain definition on purpose: it
            # replaces the module's sway defaults instead of merging with them.
            # repeat=false and allow-when-locked=true become --no-repeat/--locked.
            keybindings = {
              # overview (niri toggle-overview)
              "--no-repeat ${mod}+d" = "scale_workspaces toggle";

              # DMS
              "--no-repeat ${mod}+BackSpace" = ipc "powermenu toggle";
              "--no-repeat ${mod}+v" = ipc "clipboard toggle";
              "--no-repeat ${mod}+n" = ipc "notifications toggle";
              "${mod}+space" = ipc "spotlight toggle";

              # focus column / window
              "${mod}+h" = "focus left";
              "${mod}+j" = "focus down";
              "${mod}+k" = "focus up";
              "${mod}+l" = "focus right";

              # move column / window
              "${mod}+Shift+h" = "move left";
              "${mod}+Shift+j" = "move down";
              "${mod}+Shift+k" = "move up";
              "${mod}+Shift+l" = "move right";

              # focus monitor
              "${mod}+Ctrl+h" = "focus output left";
              "${mod}+Ctrl+j" = "focus output down";
              "${mod}+Ctrl+k" = "focus output up";
              "${mod}+Ctrl+l" = "focus output right";

              # workspaces
              "${mod}+i" = helper "workspace up";
              "${mod}+u" = helper "workspace down";
              "${mod}+Shift+i" = helper "move up";
              "${mod}+Shift+u" = helper "move down";
              "${mod}+Ctrl+i" = helper "swap up";
              "${mod}+Ctrl+u" = helper "swap down";

              # move column to monitor
              "${mod}+Shift+Ctrl+h" = "move container to output left; focus output left";
              "${mod}+Shift+Ctrl+j" = "move container to output down; focus output down";
              "${mod}+Shift+Ctrl+k" = "move container to output up; focus output up";
              "${mod}+Shift+Ctrl+l" = "move container to output right; focus output right";

              "${mod}+r" = "exec ${lib.getExe pkgs.pavucontrol} -t 3";

              "${mod}+comma" = helper "consume left";
              "${mod}+period" = helper "consume right";
              "${mod}+slash" = helper "expel";

              # preset widths / heights
              "${mod}+semicolon" = "cycle_size h next";
              "${mod}+apostrophe" = "cycle_size v next";

              # center column / all visible. scroll can't pan to a group of
              # columns, so this one fits them to the screen instead.
              "${mod}+c" = "align center";
              "${mod}+Ctrl+c" = "fit_size h visible proportional";

              # fullscreen / maximize column / maximize window to edges
              "${mod}+Return" = "fullscreen";
              "${mod}+f" = helper "maximize-column";
              "${mod}+Shift+f" = "toggle_size this 1.0 1.0";

              # screenshots
              "${mod}+p" = ''exec ${lib.getExe pkgs.grim} -g "$(${lib.getExe pkgs.slurp})" - | ${lib.getExe pkgs.swappy} -f -'';
              "${mod}+Shift+p" = "exec ${lib.getExe pkgs.grim} - | ${lib.getExe pkgs.swappy} -f -";

              # apps
              "${mod}+t" = "exec ${lib.getExe pkgs.kitty}";
              "${mod}+b" = "exec ${lib.getExe config.functorOS.programs.defaultBrowser}";
              "${mod}+m" = "exec ${lib.getExe pkgs.thunderbird}";
              "${mod}+e" = "exec ${lib.getExe pkgs.nautilus}";
              "${mod}+x" = "exec pkill -x rofi || rofi -show window";
              "${mod}+z" = "exec pkill -x wl-kbptr || ${lib.getExe pkgs.wl-kbptr}";

              "${mod}+q" = "kill";

              # hardware keys, through DMS so the OSD shows
              "--locked XF86MonBrightnessDown" = ipc "brightness decrement 5 \"\"";
              "--locked XF86MonBrightnessUp" = ipc "brightness increment 5 \"\"";
              "--locked XF86AudioRaiseVolume" = ipc "audio increment 3";
              "--locked XF86AudioLowerVolume" = ipc "audio decrement 3";
              "--locked XF86AudioMute" = ipc "audio mute";
              "XF86AudioPlay" = "exec ${lib.getExe pkgs.playerctl} --player=%any,firefox play-pause";
              "XF86AudioNext" = "exec ${lib.getExe pkgs.playerctl} --player=%any,firefox next";
              "XF86AudioRewind" = "exec ${lib.getExe pkgs.playerctl} --player=%any,firefox previous";

              # scroll-only, on keys niri left free: layout mode and numbered workspaces
              "${mod}+bracketleft" = "set_mode h";
              "${mod}+bracketright" = "set_mode v";
              "${mod}+Shift+c" = "reload";
            }
            // lib.listToAttrs (
              # 1-9 only: scroll starts on the first workspace it finds bound,
              # and Mod+0 would sort first and make that 10.
              lib.concatMap (n: [
                { name = "${mod}+${toString n}"; value = "workspace number ${toString n}"; }
                { name = "${mod}+Shift+${toString n}"; value = "move container to workspace number ${toString n}; workspace number ${toString n}"; }
              ]) (lib.range 1 9)
            );

            # niri has no resize mode, and the module's default binds both Down
            # and down, which scroll flags as a config error at every login.
            modes = { };

            # niri focus-at-startup
            startup = lib.optional (startupOutput != null) {
              command = "scrollmsg focus output '${startupOutput}'";
            };
          };

          # Things the hm option set does not model.
          extraConfig = ''
            # ---- layout: match niri's presets ----
            layout_default_width 0.5
            layout_default_height 1.0
            layout_widths [0.33333 0.5 0.66667]
            layout_heights [0.33333 0.5 0.66667 1.0]
            # niri always-center-single-column
            center_horizontal_if_fits true
            center_vertical_if_fits false
            align_reset_auto true
            cycle_size_wrap true

            # ---- gapless, square ----
            smart_gaps off
            smart_borders off
            floating_modifier ${mod} normal

            # ---- overview / jump labels in theme colours ----
            jump_labels_color ${c.base0A}
            jump_labels_background ${c.base00}
            workspace_labels_color ${c.base05}
            workspace_labels_background ${c.base00}

            # niri's window-rule opacity 0.95. DMS's own windows stay opaque.
            for_window [app_id=".*"] opacity 0.95
            for_window [class=".*"] opacity 0.95
            for_window [app_id="^com\\.danklinux\\.dms$"] floating enable, opacity 1.0

            # ---- no equivalent in scroll (niri had these) ----
            # - niri blur.kdl background-effect: scroll has no blur. DMS's own
            #   blurEnabled still blurs its panels.
            # - focus-ring: dimmed inactive windows instead, see `window` above.
          '';
        };
      };
    };
}

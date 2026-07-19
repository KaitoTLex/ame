{ lib, ... }:
{
  home-manager.users.kaitotlex =
    { options, ... }:
    {
      # Two independent upstream fixes to DMS's idle-inhibitor ("caffeine")
      # bar widget, applied by patching the QML after it's copied into
      # $out in the dms-shell derivation's own postInstall (see flake.nix
      # in the dms-shell source: postInstall does
      # `cp -r ${rootSrc}/quickshell/. $out/share/quickshell/dms/`, so the
      # files exist as plain writable text at that path by the time our
      # extra postInstall runs).
      programs.dank-material-shell.package = lib.mkForce (
        options.programs.dank-material-shell.package.default.overrideAttrs (old: {
          postInstall =
            let
              # 1. Toggling the widget off only ever flipped the QML-side
              #    SessionService.idleInhibited bool; the actual Wayland
              #    zwp_idle_inhibitor_v1 object lives in DankBarWindow.qml's
              #    `IdleInhibitor { enabled: ... }` and never got torn down
              #    reliably on enabled:false (state flips correctly --
              #    verified via `dms ipc call inhibit` round-tripping fine
              #    both ways -- but the system kept staying awake). Wrapping
              #    it in a Loader forces the native object to be fully
              #    destroyed and recreated on every toggle instead of
              #    relying on the enabled binding to release it.
              oldIdleInhibitor = "    IdleInhibitor {\n        window: barWindow\n        enabled: SessionService.idleInhibited\n    }";
              newIdleInhibitor = "    Loader {\n        active: SessionService.idleInhibited\n        sourceComponent: Component {\n            IdleInhibitor {\n                window: barWindow\n                enabled: true\n            }\n        }\n    }";

              # 2. Swap the bar widget's Material Symbols icon for the
              #    requested Nerd Font glyphs: nf-md-flask_empty_off_outline
              #    (off, U+F13F5) / nf-fa-flask (on, U+F0C3). DankNFIcon
              #    already bundles a Nerd Font and does name->glyph lookup,
              #    so just register the two names it's missing and point
              #    the widget at it instead of DankIcon.
              oldIconMapOpen = "readonly property var iconMap: ({";
              newIconMapOpen = "readonly property var iconMap: ({\n            \"flask_on\": \"\\u{f0c3}\",\n            \"flask_off\": \"\\u{f13f5}\",";
            in
            old.postInstall
            + ''
              substituteInPlace $out/share/quickshell/dms/Modules/DankBar/DankBarWindow.qml \
                --replace-fail ${lib.escapeShellArg oldIdleInhibitor} ${lib.escapeShellArg newIdleInhibitor}

              substituteInPlace $out/share/quickshell/dms/Widgets/DankNFIcon.qml \
                --replace-fail ${lib.escapeShellArg oldIconMapOpen} ${lib.escapeShellArg newIconMapOpen}

              substituteInPlace $out/share/quickshell/dms/Modules/DankBar/Widgets/IdleInhibitor.qml \
                --replace-fail 'DankIcon {' 'DankNFIcon {' \
                --replace-fail 'name: SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"' 'name: SessionService.idleInhibited ? "flask_on" : "flask_off"'
            '';
        })
      );

      programs.dank-material-shell.settings.barConfigs = lib.mkForce [
        {
          id = "default";
          name = "Main Bar";
          enabled = true;
          position = 0;
          screenPreferences = [ "all" ];
          showOnLastDisplay = true;
          leftWidgets = [
            "launcherButton"
            "workspaceSwitcher"
            {
              id = "focusedWindow";
              enabled = true;
              focusedWindowSize = 1;
            }
            {
              id = "clock";
              enabled = true;
              clockCompactMode = true;
            }
          ];
          centerWidgets = [ ];
          rightWidgets = [
            {
              id = "systemTray";
              enabled = true;
            }
            # DMS has no standalone "bluetooth" bar widget -- bluetooth only
            # appears as a row inside the controlCenterButton popup, or as a
            # StatusNotifierItem icon inside systemTray if a bluetooth applet is
            # running. Placed immediately after systemTray, the spot where a
            # bluetooth tray icon would actually cluster.
            {
              id = "idleInhibitor";
              enabled = true;
            }
            {
              id = "music";
              enabled = true;
            }
            {
              id = "clipboard";
              enabled = true;
            }
            {
              id = "notificationButton";
              enabled = true;
            }
            {
              id = "battery";
              enabled = true;
            }
            {
              id = "controlCenterButton";
              enabled = true;
            }
          ];
          spacing = 4;
          innerPadding = 4;
          bottomGap = 0;
          transparency = 1;
          widgetTransparency = 1;
          squareCorners = false;
          noBackground = false;
          gothCornersEnabled = false;
          gothCornerRadiusOverride = false;
          gothCornerRadiusValue = 12;
          borderEnabled = false;
          borderColor = "surfaceText";
          borderOpacity = 1;
          borderThickness = 1;
          fontScale = 1;
          autoHide = false;
          autoHideDelay = 250;
          openOnOverview = false;
          visible = true;
          popupGapsAuto = true;
          popupGapsManual = 4;
        }
      ];
    };
}

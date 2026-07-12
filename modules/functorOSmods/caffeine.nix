{ lib, ... }:
{
  home-manager.users.kaitotlex.programs.dank-material-shell.settings.barConfigs = lib.mkForce [
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
}

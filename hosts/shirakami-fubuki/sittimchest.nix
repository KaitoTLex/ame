{ pkgs, ... }:
{
  # Keep the live checkout: UI edits take effect on service restart.
  # Dependencies are installed in this checkout, not fetched at service startup.
  users.users.kaitotlex.linger = true;
  home-manager.users.kaitotlex.systemd.user.services.sittimchest = {
    Unit = {
      Description = "Sittim Chest task and knowledge workspace";
      After = [ "network.target" ];
      StartLimitIntervalSec = 60;
      StartLimitBurst = 5;
    };
    Service = {
      Type = "simple";
      WorkingDirectory = "/home/kaitotlex/Source/Playground/sittimchest";
      ExecStart = "${pkgs.bun}/bin/bun src/server.ts";
      Environment = [
        "SITTIM_VAULT=/home/kaitotlex/Frontier"
        "SITTIM_STATE=/home/kaitotlex/.sittim"
        "SITTIM_PORT=7348"
        "SITTIM_HOST=0.0.0.0"
        "SITTIM_TZ=America/New_York"
      ];
      Restart = "on-failure";
      RestartSec = 3;
      TimeoutStopSec = 20;
      UMask = "0077";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    Install.WantedBy = [ "default.target" ];
  };
}

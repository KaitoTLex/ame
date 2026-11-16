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
        # Reuse the same loopback SSH tunnel and Tabby queue as La+/Marine.
        # Do not open a separate inference server or change the loaded model.
        "SITTIM_LECTURER_LLM_URL=http://127.0.0.1:8090/v1/chat/completions"
        "SITTIM_LECTURER_MODEL=Qwen3.8-Flash-Next-Uncensored-exl3-5bpw"
        # Sidecar deployment is independent; its default differs from the app.
        "SITTIM_LECTURER_TTS_URL=http://127.0.0.1:9881"
      ];
      Restart = "on-failure";
      RestartSec = 3;
      TimeoutStopSec = 20;
      UMask = "0077";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    # Not autostarted on this host; start by hand with systemctl --user if needed.
  };
}

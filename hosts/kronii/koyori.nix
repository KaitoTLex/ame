# koyori print-farm hub, shown as "Takanashi Kiara". systemd starts it, and go2rtc
# for the cameras, at every boot. The web UI is served on port 80 to the LAN and the
# tailnet: http://kronii/ or http://192.168.1.112/. Printers and their PrusaLink keys
# are added in the web UI and kept in /var/lib/koyori, never in the Nix store.
#
# Access is by Tailscale identity: admins below, other tailnet users and the LAN can
# only look. Turn Tailscale on to control printers.
#
# The options come from koyori's own NixOS module (nix/module.nix in its checkout),
# which unpublished.nix imports; this file only configures it.
{ ... }:
{
  services.koyori = {
    hub.enable = true;
    hub.openFirewall = true;
    # HTTPS on the tailnet name too, with a certificate from tailscale (renewed by
    # itself): browsers only offer notifications to HTTPS pages. Open
    # https://kronii.tail7070c8.ts.net from a device on the tailnet to turn them on.
    hub.https = {
      enable = true;
      domain = "kronii.tail7070c8.ts.net";
    };
    # WebRTC for live camera view from browsers on the LAN.
    go2rtc.openFirewall = true;
    # farm-detector: runs the failure model for the hub, on localhost only, on the Tesla
    # V100 (GPU 0 in nvidia-smi; the RTX 3050 is GPU 1, for koyori-train). It loads every
    # model at start and keeps it warm, and restarts itself if the GPU stops answering.
    # The V100 is Volta (compute capability 7.0): koyori builds onnxruntime for it against
    # CUDA 12 and cuDNN 9.11.1, the last releases that support it. Models are added in the
    # web UI (Settings, Detector) or with farmctl model add.
    detector.enable = true;
    detector.gpu = 0;
    detector.cudaCapabilities = [ "7.0" ];
    # Score every camera all the time, not only while its printer prints (koyori's
    # [detector] idle): idle frames are logged and sampled, never judged, so a bare
    # bed can't pause anything. Six cameras every 5 s is nothing for the V100.
    settings.detector.idle = true;
    settings.auth = {
      # Tailscale logins. Everyone else on the tailnet can look; the LAN is read-only.
      admins = [ "ren@alpa.ca" ];
    };
    # The farm's slicing defaults, over every Prusa preset: the web UI starts from them
    # and anything changed there still wins.
    settings.slicer.defaults = {
      fill_density = "20%";
      fill_pattern = "gyroid";
      support_material = "1";
      support_material_auto = "1";
      support_material_buildplate_only = "1";
      support_material_style = "organic";
    };
    settings.hub = {
      site_name = "Takanashi Kiara";
      listen_host = "0.0.0.0";
      listen_port = 80;
      # Every name and address the site is opened by; others get 403.
      allowed_hosts = [
        "kronii"
        "kronii.local"
        "kronii.tail7070c8.ts.net"
        "192.168.1.112"
        "100.79.234.116"
        "localhost"
        "127.0.0.1"
      ];
    };
  };

  # farm-detector builds its ONNX sessions once, when it starts. On 2026-11-15 it
  # started a second before the nvidia modules loaded, CUDA found no device, and it
  # ran the model on the CPU until restarted. nvidia-persistenced initialises the
  # cards; start after it.
  systemd.services.farm-detector = {
    after = [ "nvidia-persistenced.service" ];
    wants = [ "nvidia-persistenced.service" ];
  };

  # At boot koyori-cert runs right after tailscaled starts, but `tailscale cert` fails
  # ("no netmap available") until tailscale has connected, about 10 s later. Wait for
  # that, though not forever: the hub starts after this, and it serves the LAN too.
  systemd.services.koyori-cert.preStart = "tailscale wait --timeout=1m";
}

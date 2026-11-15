# koyori print-farm hub, shown as "Takanashi Kiara". systemd starts it, and go2rtc
# for the cameras, at every boot. The web UI is served on port 80 to the LAN and the
# tailnet: http://osaka/ or http://192.168.1.112/. Printers and their PrusaLink keys
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
    # https://osaka.tail7070c8.ts.net from a device on the tailnet to turn them on.
    hub.https = {
      enable = true;
      domain = "osaka.tail7070c8.ts.net";
    };
    # WebRTC for live camera view from browsers on the LAN.
    go2rtc.openFirewall = true;
    # farm-detector: runs the failure model for the hub, on localhost only, on the RTX
    # 3050 (GPU 1 in nvidia-smi; GPU 0 is the V100, which belongs to another project).
    # Models are added in the web UI (Settings, Detector) or with farmctl model add.
    detector.enable = true;
    detector.gpu = 1;
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
        "osaka"
        "osaka.local"
        "osaka.tail7070c8.ts.net"
        "192.168.1.112"
        "100.79.234.116"
        "localhost"
        "127.0.0.1"
      ];
    };
  };

  # At boot koyori-cert runs right after tailscaled starts, but `tailscale cert` fails
  # ("no netmap available") until tailscale has connected, about 10 s later. Wait for
  # that, though not forever: the hub starts after this, and it serves the LAN too.
  systemd.services.koyori-cert.preStart = "tailscale wait --timeout=1m";
}

{ lib, pkgs, ... }:
let
  spotify-asahi = pkgs.mkFexApp {
    pname = "spotify";
    package = pkgs.x86.spotify;
    meta.description = "Spotify (x86_64 via muvm and FEX-Emu)";
  };

  spotify-desktop = pkgs.makeDesktopItem {
    name = "spotify-asahi";
    desktopName = "Spotify";
    comment = "Spotify on Apple Silicon via muvm and FEX-Emu";
    exec = "${lib.getExe spotify-asahi} %U";
    icon = "${pkgs.x86.spotify}/share/icons/hicolor/256x256/apps/spotify-client.png";
    categories = [
      "Audio"
      "Music"
      "Player"
      "AudioVideo"
    ];
    mimeTypes = [ "x-scheme-handler/spotify" ];
    startupWMClass = "spotify";
  };
in
{
  # FunctorOS only enables Spicetify on x86_64, but keep it explicitly off on
  # this host so it cannot replace the FEX-wrapped package in the future.
  home-manager.users.kaitotlex.programs.spicetify.enable = lib.mkForce false;

  environment.systemPackages = [
    spotify-asahi
    spotify-desktop
  ];
}

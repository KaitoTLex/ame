# Upstream AppImage: nixpkgs' bambu-studio isn't in the binary cache.
{
  lib,
  appimageTools,
  fetchurl,
}:
let
  pname = "bambu-studio";
  version = "02.08.02.61";
  src = fetchurl {
    url = "https://github.com/bambulab/BambuStudio/releases/download/v${version}/BambuStudio_ubuntu24.04-v${version}-20260820225108.AppImage";
    hash = "sha256-1QGxA/rFQkUT7A6Na8FF+zBxneLH2U1zINcjdAyBp/0=";
  };
  extracted = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs =
    pkgs: with pkgs; [
      webkitgtk_4_1
      glib-networking
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
    ];

  # Exits 255 at startup on native Wayland; run it through XWayland.
  profile = ''
    export GDK_BACKEND=x11
  '';

  extraInstallCommands = ''
    install -Dm444 ${extracted}/BambuStudio.desktop $out/share/applications/bambu-studio.desktop
    substituteInPlace $out/share/applications/bambu-studio.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
    cp -r ${extracted}/usr/share/icons $out/share/
  '';

  meta = {
    description = "Slicer for Bambu Lab 3D printers";
    homepage = "https://github.com/bambulab/BambuStudio";
    license = lib.licenses.agpl3Only;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };
}

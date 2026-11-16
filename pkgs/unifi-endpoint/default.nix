{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  patchelf,
  fontconfig,
  glib,
  gtk3,
  icu,
  krb5,
  libGL,
  libICE,
  libSM,
  libX11,
  libXcursor,
  libXext,
  libXi,
  libXrandr,
  openssl,
  vulkan-loader,
  zlib,
}:
# The .deb ships self-contained, single-file .NET binaries. These carry their
# payload appended to the ELF, so they must not be stripped, and nothing in here
# can be wrapped: the daemon re-executes the app and the root helper by their
# absolute /usr/lib/UniFi-Endpoint paths. Libraries the runtime dlopen()s (ICU,
# OpenSSL, X11, ...) therefore go in the RUNPATH, which also survives the
# environment reset pkexec does before starting the helper.
let
  runtimeLibs = [
    fontconfig
    glib
    gtk3
    icu
    krb5
    libGL
    libICE
    libSM
    libX11
    libXcursor
    libXext
    libXi
    libXrandr
    openssl
    stdenv.cc.cc.lib
    vulkan-loader
    zlib
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "unifi-endpoint";
  version = "1.1.7-28";

  src = fetchurl {
    url = "https://fw-download.ubnt.com/data/unifi-endpoint-desktop-app-deb/55c2-linux-1.1.7-28-54b0e439-ddb5-41be-9e6f-56739775cdd9.deb";
    hash = "sha256:996cd570c30dc3ec95203eef0bc85ef7683b999ade3e55cadc3ddbed75ae59ad";
  };

  nativeBuildInputs = [
    dpkg
    patchelf
  ];

  dontUnpack = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    dpkg-deb -x $src root
    mkdir -p $out/lib $out/share
    cp -r root/usr/lib/UniFi-Endpoint $out/lib/UniFi-Endpoint
    cp -r root/usr/lib/systemd $out/lib/systemd
    cp -r root/usr/share/{applications,icons,polkit-1} $out/share/
    mkdir -p $out/share/unifi-endpoint
    cp root/etc/polkit-1/rules.d/50-unifi-endpoint.rules $out/share/unifi-endpoint/
    cp root/etc/NetworkManager/conf.d/90-unifi-endpoint-unmanaged-vpn.conf $out/share/unifi-endpoint/

    substituteInPlace $out/lib/systemd/user/UniFi-Endpoint-Daemon.service \
      --replace-fail /usr/lib/UniFi-Endpoint/ $out/lib/UniFi-Endpoint/
    substituteInPlace $out/share/applications/unifi-endpoint.desktop \
      --replace-fail /usr/lib/UniFi-Endpoint/ $out/lib/UniFi-Endpoint/

    for bin in UIDSTD.Avalonia UniFi-Endpoint-Daemon UniFi-Endpoint-PrivilegedHelper utunnel; do
      patchelf \
        --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
        --set-rpath ${lib.makeLibraryPath runtimeLibs} \
        $out/lib/UniFi-Endpoint/$bin
    done
    for so in libHarfBuzzSharp.so libSkiaSharp.so libsodium.so; do
      patchelf --set-rpath ${lib.makeLibraryPath runtimeLibs} $out/lib/UniFi-Endpoint/$so
    done

    runHook postInstall
  '';

  meta = {
    description = "UniFi network access client (VPN, Wi-Fi, credentials)";
    homepage = "https://www.ui.com/download/app/endpoint-desktop";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "UIDSTD.Avalonia";
  };
})

{
  lib,
  stdenvNoCC,
  writeShellApplication,
  symlinkJoin,
  makeDesktopItem,
  muvm,
  fex,
  fexInit,
  coreutils,
  gnugrep,
  squashfuse,
  erofs-utils,
  steam-unwrapped,
  extraEnv ? {
    FEX_X87REDUCEDPRECISION = "1";
    FEX_MULTIBLOCK = "0";
    PROTON_USE_WINED3D = "1";
  },
}:
let
  extraEnvExports = lib.concatStringsSep " " (
    lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value};") extraEnv
  );
  ensureRootfs = import ./fex-rootfs.nix { inherit lib fex; };

  steamBootstrap = stdenvNoCC.mkDerivation {
    name = "steam-bootstrap-${steam-unwrapped.version}";
    inherit (steam-unwrapped) src;
    dontBuild = true;
    dontPatchShebangs = true;
    installPhase = ''
      mkdir -p "$out/steam-launcher"
      cp bin_steam.sh bootstraplinux_ubuntu12_32.tar.xz steam_subscriber_agreement.txt \
        "$out/steam-launcher/"
    '';
  };

  desktopItem = makeDesktopItem {
    name = "asahi-steam";
    desktopName = "Steam";
    comment = "Steam on Apple Silicon through muvm and FEX";
    exec = "asahi-steam %U";
    icon = "steam";
    categories = [
      "Game"
      "Network"
    ];
    mimeTypes = [
      "x-scheme-handler/steam"
      "x-scheme-handler/steamlink"
    ];
  };

  launcher = writeShellApplication {
    name = "asahi-steam";
    runtimeInputs = [
      coreutils
      gnugrep
      squashfuse
      erofs-utils
    ];
    text = ''
      die() { echo "ERROR: $1" >&2; exit 1; }
      [[ "$(id -u)" -ne 0 ]] || die "Do not run asahi-steam as root"

      ${ensureRootfs}
      data_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/asahi-steam"
      marker="$data_dir/bootstrap-installed"

      if [[ ! -f "$marker" || ! -f "$data_dir/steam-launcher/bin_steam.sh" ]]; then
        echo "Setting up the Steam bootstrap..."
        mkdir -p "$data_dir"
        cp -a ${steamBootstrap}/steam-launcher "$data_dir/"
        printf 'ok\n' > "$marker"
      fi

      uid=$(id -u)
      exec ${lib.getExe muvm} \
        --gpu-mode=venus \
        --execute-pre ${lib.getExe fexInit} \
        --interactive \
        -e "PRESSURE_VESSEL_FILESYSTEMS_RO=/nix:/run/opengl-driver" \
        -- \
        FEXBash -c "\
          export PULSE_SERVER=unix:/run/user/$uid/pulse/native; \
          export SDL_AUDIODRIVER=pulseaudio; \
          export LC_ALL=C.UTF-8; \
          export LANG=C.UTF-8; \
          export LOCALE_ARCHIVE=/run/current-system/sw/lib/locale/locale-archive; \
          ${extraEnvExports}
          exec $data_dir/steam-launcher/bin_steam.sh -cef-force-occlusion \"\$@\"" \
          asahi-steam "$@"
    '';
    meta = {
      description = "Steam launcher for Apple Silicon through muvm and FEX";
      license = lib.licenses.mit;
      mainProgram = "asahi-steam";
      platforms = [ "aarch64-linux" ];
    };
  };
in
symlinkJoin {
  name = "asahi-steam";
  paths = [
    launcher
    desktopItem
  ];
  postBuild = ''
    mkdir -p "$out/share"
    ln -s ${steam-unwrapped}/share/icons "$out/share/icons"
  '';
  inherit (launcher) meta;
}

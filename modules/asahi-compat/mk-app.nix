{
  lib,
  writeShellApplication,
  coreutils,
  gnugrep,
  muvm,
  fex,
  fexInit,
}:
{
  pname,
  package,
  binName ? package.meta.mainProgram or pname,
  extraEnv ? { },
  meta ? { },
}:
let
  extraEnvExports = lib.concatStringsSep " " (
    lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value};") extraEnv
  );
  ensureRootfs = import ./fex-rootfs.nix { inherit lib fex; };
in
writeShellApplication {
  name = pname;
  runtimeInputs = [
    coreutils
    gnugrep
  ];
  text = ''
    die() { echo "ERROR: $1" >&2; exit 1; }
    [[ "$(id -u)" -ne 0 ]] || die "Do not run ${pname} as root"

    ${ensureRootfs}
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
        exec ${package}/bin/${binName} \"\$@\"" ${pname} "$@"
  '';
  meta = {
    mainProgram = pname;
    platforms = [ "aarch64-linux" ];
  }
  // meta;
}

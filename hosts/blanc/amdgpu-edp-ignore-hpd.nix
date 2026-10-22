# Internal OLED goes dark as soon as amdgpu takes over from the GOP. The
# panel sits behind the Advanced Optimus eDP mux (PI3WVR13612) and its HPD
# never reaches the 780M under Linux, although the firmware still lights it
# (Windows did too). amdgpu powers the eDP, waits 300 ms for HPD, then calls
# it disconnected and powers it back off; its AUX engine also aborts DPCD/EDID
# reads while HPD is low. This rebuilds just amdgpu.ko with eDP treated as
# connected and AUX_IGNORE_HPD_DISCON (AUX_CONTROL bit 16) set on the eDP
# AUX channel, like hosts/nanashi/ttm-swapout-fix.nix. Drop it once the
# panel raises HPD again (the build fails on --replace-fail if upstream moves).
{
  lib,
  stdenv,
  kernel,
}:
stdenv.mkDerivation {
  pname = "amdgpu-edp-ignore-hpd";
  inherit (kernel) version src;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  unpackPhase = ''
    runHook preUnpack
    tar -xf $src --strip-components=1 --wildcards '*/drivers/gpu/drm/amd'
    runHook postUnpack
  '';

  postPatch = ''
    substituteInPlace drivers/gpu/drm/amd/display/dc/link/link_detection.c --replace-fail \
      '	if (link_get_hpd_state(link)) {
    		*type = dc_connection_single;' \
      '	if (link_get_hpd_state(link) || link->connector_signal == SIGNAL_TYPE_EDP) {
    		*type = dc_connection_single;'

    substituteInPlace drivers/gpu/drm/amd/display/dc/dio/dcn10/dcn10_link_encoder.c --replace-fail \
      '	AUX_REG_UPDATE_2(AUX_CONTROL,
    			AUX_HPD_SEL, hpd_source,
    			AUX_LS_READ_EN, 0);' \
      '	AUX_REG_UPDATE_2(AUX_CONTROL,
    			AUX_HPD_SEL, hpd_source,
    			AUX_LS_READ_EN, 0);

    	/* AUX_IGNORE_HPD_DISCON: let eDP AUX run without HPD. */
    	if (enc10->base.connector.id == CONNECTOR_ID_EDP)
    		generic_reg_update_ex(CTX, AUX_REG(AUX_CONTROL), 1, 16, 0x00010000, 1);'

    # The tracepoint header is found relative to the kernel tree, which an
    # out-of-tree build lacks; resolve it through -I like amdgpu_dm_trace.h.
    substituteInPlace drivers/gpu/drm/amd/amdgpu/amdgpu_trace.h --replace-fail \
      '#define TRACE_INCLUDE_PATH ../../drivers/gpu/drm/amd/amdgpu' \
      '#define TRACE_INCLUDE_PATH .'
  '';

  # See hosts/nanashi/snd-acp-config.nix.
  makeFlags =
    lib.filter (f: !(lib.hasPrefix "O=" f || lib.hasPrefix "--eval" f)) kernel.makeFlags
    ++ [
      "-C"
      "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    ];

  enableParallelBuilding = true;

  buildPhase = ''
    runHook preBuild
    make $makeFlags -j$NIX_BUILD_CORES M="$PWD/drivers/gpu/drm/amd/amdgpu" modules
    runHook postBuild
  '';

  # updates/ takes precedence over the in-tree module.
  installPhase = ''
    runHook preInstall
    install -Dm444 drivers/gpu/drm/amd/amdgpu/amdgpu.ko \
      $out/lib/modules/${kernel.modDirVersion}/updates/amdgpu.ko
    install -Dm444 /dev/stdin $out/etc/depmod.d/amdgpu.conf <<'EOF'
    override amdgpu * updates
    EOF
    runHook postInstall
  '';

  meta = {
    description = "amdgpu.ko that drives the GA403 eDP panel without HPD";
    platforms = [ "x86_64-linux" ];
    license = lib.licenses.gpl2Only;
  };
}

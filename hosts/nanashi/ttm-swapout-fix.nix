# niri/GPU lock-ups minutes after resuming from hibernation (drm/amd#5387).
# ttm_bo_swapout_cb() checks `!ret`, but ttm_tt_swapout() returns the page
# count on success. Swapped-out BOs then stay in their bulk_move range after
# being freed, and the LRU gets corrupted. Upstream fix: drm-misc-fixes
# 3db7d7d58341, Cc stable v7.1+. Rebuilds just ttm.ko, like
# snd-acp-config.nix. Drop it once the kernel has the fix (--replace-fail
# then fails the build).
{
  lib,
  stdenv,
  kernel,
}:
stdenv.mkDerivation {
  pname = "ttm-swapout-fix";
  inherit (kernel) version src;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  unpackPhase = ''
    runHook preUnpack
    tar -xf $src --strip-components=1 --wildcards '*/drivers/gpu/drm/ttm'
    runHook postUnpack
  '';

  postPatch = ''
    substituteInPlace drivers/gpu/drm/ttm/ttm_bo.c --replace-fail \
      '		ret = ttm_tt_swapout(bdev, tt, swapout_walk->gfp_flags);
    		if (!ret) {' \
      '		ret = ttm_tt_swapout(bdev, tt, swapout_walk->gfp_flags);
    		if (ret > 0) {'

    # Build ttm.o alone, without the KUnit tests/ subdirectory.
    cat > drivers/gpu/drm/ttm/Kbuild <<'EOF'
    ttm-y := ttm_tt.o ttm_bo.o ttm_bo_util.o ttm_bo_vm.o ttm_module.o \
    	ttm_execbuf_util.o ttm_range_manager.o ttm_resource.o ttm_pool.o \
    	ttm_device.o ttm_sys_manager.o ttm_backup.o
    ttm-$(CONFIG_AGP) += ttm_agp_backend.o
    obj-m := ttm.o
    EOF
  '';

  # See snd-acp-config.nix.
  makeFlags =
    lib.filter (f: !(lib.hasPrefix "O=" f || lib.hasPrefix "--eval" f)) kernel.makeFlags
    ++ [
      "-C"
      "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    ];

  buildPhase = ''
    runHook preBuild
    make $makeFlags M="$PWD/drivers/gpu/drm/ttm" modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 drivers/gpu/drm/ttm/ttm.ko \
      $out/lib/modules/${kernel.modDirVersion}/updates/ttm.ko
    install -Dm444 /dev/stdin $out/etc/depmod.d/ttm.conf <<'EOF'
    override ttm * updates
    EOF
    runHook postInstall
  '';

  meta = {
    description = "ttm.ko with the hibernation swapout bulk_move fix (drm/amd#5387)";
    platforms = [ "x86_64-linux" ];
    license = lib.licenses.gpl2Only;
  };
}

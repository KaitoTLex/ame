# Internal speakers/jack/mics (RT721 on ACP 7.0 SoundWire). The BIOS
# acp-audio-config-flag picks the legacy DMIC-only driver, which leaves only
# HDMI audio. Upstream works around this per model in
# acp70_acpi_flag_override_table; this rebuilds just snd-acp-config with the
# FA401EA added. Drop it once upstream lists the FA401EA (the build then fails
# on --replace-fail).
{
  lib,
  stdenv,
  kernel,
}:
stdenv.mkDerivation {
  pname = "snd-acp-config-fa401ea";
  inherit (kernel) version src;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  # acp-config.c includes ../sof/amd/acp.h.
  unpackPhase = ''
    runHook preUnpack
    tar -xf $src --strip-components=1 --wildcards '*/sound/soc/amd' '*/sound/soc/sof'
    runHook postUnpack
  '';

  postPatch = ''
    substituteInPlace sound/soc/amd/acp-config.c --replace-fail \
      'static const struct dmi_system_id acp70_acpi_flag_override_table[] = {' \
      'static const struct dmi_system_id acp70_acpi_flag_override_table[] = {
    	{
    		/* ASUS TUF Gaming A14 FA401EA (Strix Halo, ACP 7.0, RT721) */
    		.matches = {
    			DMI_MATCH(DMI_BOARD_VENDOR, "ASUSTeK COMPUTER INC."),
    			DMI_MATCH(DMI_PRODUCT_NAME, "FA401EA"),
    		},
    	},'

    # Kbuild overrides the Makefile, so only this module is built.
    cat > sound/soc/amd/Kbuild <<'EOF'
    obj-m := snd-acp-config.o
    snd-acp-config-y := acp-config.o
    EOF
  '';

  # Drop the flags that only apply inside the kernel's own build tree.
  makeFlags =
    lib.filter (f: !(lib.hasPrefix "O=" f || lib.hasPrefix "--eval" f)) kernel.makeFlags
    ++ [
      "-C"
      "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    ];

  buildPhase = ''
    runHook preBuild
    make $makeFlags M="$PWD/sound/soc/amd" modules
    runHook postBuild
  '';

  # updates/ takes precedence over the in-tree module.
  installPhase = ''
    runHook preInstall
    install -Dm444 sound/soc/amd/snd-acp-config.ko \
      $out/lib/modules/${kernel.modDirVersion}/updates/snd-acp-config.ko
    install -Dm444 /dev/stdin $out/etc/depmod.d/snd-acp-config.conf <<'EOF'
    override snd_acp_config * updates
    EOF
    runHook postInstall
  '';

  meta = {
    description = "snd-acp-config with the ASUS FA401EA in the ACP 7.0 BIOS-flag override table";
    platforms = [ "x86_64-linux" ];
    license = lib.licenses.gpl2Only;
  };
}

{
  lib,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  installShellFiles,
  stdenv,
  openssl,
  curl,
  autoAddDriverRunpath,
  cudaPackages,
  # sm_120 (Blackwell / RTX 50-series). Override for other cards.
  cudaCapabilities ? [ "12.0" ],
}:
# PrismML's llama.cpp fork.
#
# Why this exists: PQ2_0 and PTQ1_0 are Prism-private quantisation formats
# (ggml.h: GGML_TYPE_PQ2_0 = 142, GGML_TYPE_PTQ1_0 = 143, "Prism-private
# ternary, group 128"). Mainline llama.cpp, Ollama and LM Studio cannot load a
# GGUF in either format -- the file is rejected at load, not degraded. Models
# such as BoldingBuilds/Ternary-Bonsai-2-27B-Abliterated-v2-PQ2_0-MTP-GGUF
# therefore require this build and nothing else.
#
# This is NOT nixpkgs' llama-cpp with a different src. Three things differ in
# the fork and each one breaks the nixpkgs derivation if carried over:
#
#   1. No web UI. `tools/server/webui/package-lock.json` does not exist, so
#      nixpkgs' `npmDeps` / `npmDepsHash` / `npmConfigHook` and its
#      `npm run build` in preConfigure have nothing to act on. All of it is
#      dropped here, along with nodejs and npmHooks.
#   2. No `tools/server/public/index.html.gz`, so nixpkgs' postPatch
#      (`rm tools/server/public/index.html.gz`) would fail. Dropped.
#   3. The fork adds `LLAMA_BUILD_UI`, `LLAMA_BUILD_HTML` and `LLAMA_BUILD_APP`
#      options that mainline does not have. UI and HTML are forced off; without
#      that, cmake looks for the absent web assets.
let
  inherit (lib) cmakeBool cmakeFeature;
in
cudaPackages.backendStdenv.mkDerivation (finalAttrs: {
  pname = "llama-cpp-prism";
  # Tag encodes the upstream build number and the fork's commit. The model card
  # for PQ2_0 builds names `prism-b10743-adfffbe` as the minimum; this is newer.
  version = "prism-b10772-e8fd209";

  src = fetchFromGitHub {
    owner = "PrismML-Eng";
    repo = "llama.cpp";
    tag = finalAttrs.version;
    hash = "sha256-0VnSQkILpKpj61GdGiM5JVcB3Z1NoJOGOtTOW/XWFSc=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    installShellFiles
    cudaPackages.cuda_nvcc
    # Rewrites the RUNPATH so the binary finds the host's libcuda.so.1 under
    # /run/opengl-driver/lib. Without it the build succeeds and every CUDA call
    # fails at runtime with "no NVIDIA driver" on a machine where nvidia-smi
    # works.
    autoAddDriverRunpath
  ];

  buildInputs = [
    openssl
    curl
    cudaPackages.cuda_cccl
    cudaPackages.cuda_cudart
    cudaPackages.libcublas
  ];

  cmakeFlags = [
    # -march=native would make the build non-deterministic and non-portable
    # across the store.
    (cmakeBool "GGML_NATIVE" false)
    (cmakeBool "GGML_CUDA" true)
    (cmakeBool "BUILD_SHARED_LIBS" true)

    (cmakeBool "LLAMA_BUILD_SERVER" true)
    (cmakeBool "LLAMA_BUILD_TOOLS" true)
    (cmakeBool "LLAMA_BUILD_COMMON" true)
    (cmakeBool "LLAMA_BUILD_EXAMPLES" false)
    (cmakeBool "LLAMA_BUILD_TESTS" false)

    # Fork-only options. The fork has no bundled web assets; leaving these on
    # makes cmake look for files that are not in the tree.
    (cmakeBool "LLAMA_BUILD_UI" false)
    (cmakeBool "LLAMA_BUILD_HTML" false)

    (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" (
      lib.concatStringsSep ";" (map (c: lib.replaceStrings [ "." ] [ "" ] c) cudaCapabilities)
    ))

    # fetchFromGitHub gives no .git, so cmake cannot derive these and the binary
    # reports "build 0, commit unknown". The PQ2_0 model cards specify a minimum
    # by build number, so this has to be readable from --version.
    (cmakeFeature "LLAMA_BUILD_NUMBER" "10772")
    (cmakeFeature "LLAMA_BUILD_COMMIT" "e8fd209")
  ];

  # Covered by installCheckPhase below.
  postInstall = null;

  # Proves PQ2_0 is compiled in, not merely declared in the header.
  #
  # The check must look in libggml-base.so, NOT in bin/llama-server. With
  # BUILD_SHARED_LIBS=true the quant tables live in ggml.c -> libggml-base.so,
  # and the server binary only links against it, so grepping the binary gives a
  # false negative. libggml-cuda.so is checked too: without it the format would
  # load but fall back to CPU, which defeats the point on this machine.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    for lib in libggml-base.so libggml-cuda.so; do
      echo "checking PQ2_0 in $lib..."
      if ! grep -qa 'PQ2_0' "$out/lib/$lib"; then
        echo "PQ2_0 absent from $lib -- wrong fork, or the format was dropped" >&2
        exit 1
      fi
    done

    if [ ! -x "$out/bin/llama-server" ]; then
      echo "llama-server missing from \$out/bin -- the fork renamed the target" >&2
      ls -1 "$out/bin" >&2
      exit 1
    fi

    echo "PQ2_0 present in CPU and CUDA backends."
    runHook postInstallCheck
  '';

  passthru.updateScript = null;

  meta = {
    description = "PrismML llama.cpp fork with PQ2_0/PTQ1_0 ternary quantisation";
    longDescription = ''
      llama.cpp fork from PrismML-Eng that implements the Prism-private
      quantisation formats PQ2_0 (group-128 Q2_0) and PTQ1_0 (group-128
      ternary). Required to load GGUF files in those formats; mainline
      llama.cpp, Ollama and LM Studio reject them outright.

      Built with CUDA for sm_120 by default. Installed alongside nixpkgs'
      `llama-cpp` rather than replacing it -- the binary names collide, so do
      not put both in one profile.
    '';
    homepage = "https://github.com/PrismML-Eng/llama.cpp";
    license = lib.licenses.mit;
    mainProgram = "llama-server";
    platforms = [ "x86_64-linux" ];
  };
})

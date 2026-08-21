inputs:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.asahiCompat;

  overlay = final: prev: rec {
    # FEX 2604/2605 does not compile with fmt 12 because fmt no longer formats
    # std::byte ranges. Keep the current FEX source and use its compatible fmt.
    fex = prev.fex.override { fmt = prev.fmt_11; };
    muvm = prev.muvm.override { inherit fex; };

    asahiX86Packages = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };

    asahiFexInit = final.callPackage ./fex-init.nix { };
    mkAsahiX86App = final.callPackage ./mk-app.nix {
      inherit fex muvm;
      fexInit = asahiFexInit;
    };
    asahiSteam = final.callPackage ./steam.nix {
      inherit fex muvm;
      fexInit = asahiFexInit;
    };
    asahiXilinx = final.callPackage ./xilinx {
      inherit asahiX86Packages mkAsahiX86App;
    };
  };
in
{
  options.programs.asahiCompat = {
    steam = {
      enable = lib.mkEnableOption "Steam on Apple Silicon through muvm and FEX";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.asahiSteam.override { inherit (cfg.steam) extraEnv; };
        defaultText = lib.literalExpression "pkgs.asahiSteam";
        description = "Steam launcher package to install.";
      };

      extraEnv = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          FEX_X87REDUCEDPRECISION = "1";
          FEX_MULTIBLOCK = "0";
          PROTON_USE_WINED3D = "1";
        };
        description = "Environment variables passed to Steam inside FEX.";
      };
    };

    xilinx = {
      enable = lib.mkEnableOption "Xilinx tools on Apple Silicon through muvm and FEX";

      tools = lib.mkOption {
        type = lib.types.listOf (
          lib.types.enum [
            "vivado"
            "vitis"
            "vitis-hls"
            "model-composer"
            "xsct"
          ]
        );
        default = [ "vivado" ];
        description = "Xilinx launchers to install.";
      };

      includeShell = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to install the Xilinx installer shell.";
      };

      extraEnv = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Environment variables passed to Xilinx tools inside FEX.";
      };
    };
  };

  config = lib.mkMerge [
    {
      nixpkgs.overlays = [ overlay ];
    }

    (lib.mkIf (cfg.steam.enable || cfg.xilinx.enable) {
      assertions = [
        {
          assertion = pkgs.stdenv.hostPlatform.system == "aarch64-linux";
          message = "programs.asahiCompat is only supported on aarch64-linux";
        }
      ];
      hardware.graphics.enable = lib.mkDefault true;
    })

    (lib.mkIf cfg.steam.enable {
      environment.systemPackages = [ cfg.steam.package ];
    })

    (lib.mkIf cfg.xilinx.enable {
      environment.systemPackages =
        map (
          tool:
          pkgs.asahiXilinx.${tool} {
            extraEnv = cfg.xilinx.extraEnv;
          }
        ) cfg.xilinx.tools
        ++ lib.optional cfg.xilinx.includeShell pkgs.asahiXilinx.xilinx-shell;

      # The FHS environments are x86_64 derivations. Most dependencies are
      # substituted, while binfmt handles build-time tools on cache misses.
      boot.binfmt.emulatedSystems = lib.mkDefault [ "x86_64-linux" ];
    })
  ];
}

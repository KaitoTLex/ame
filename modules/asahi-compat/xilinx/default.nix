{
  lib,
  asahiX86Packages,
  mkAsahiX86App,
}:
let
  x86 = asahiX86Packages;
  targetPkgs = import ./common.nix;
  commonMeta = {
    license = lib.licenses.mit;
    platforms = [ "aarch64-linux" ];
  };

  configPrefix =
    {
      requireConfig ? true,
    }:
    ''
      if [[ -f ~/.config/xilinx/nix.sh ]]; then
        source ~/.config/xilinx/nix.sh
    ''
    + lib.optionalString requireConfig ''
      else
        echo "xilinx: error: ~/.config/xilinx/nix.sh does not exist" >&2
        exit 1
      fi
      if [[ ! -d "$INSTALL_DIR" ]]; then
        echo "xilinx: error: INSTALL_DIR '$INSTALL_DIR' is not a directory" >&2
        exit 2
    ''
    + ''
      fi
    '';

  mkProduct =
    {
      product,
      description,
      extraEnv ? { },
    }:
    let
      name = lib.toLower product;
      fhsEnv = x86.buildFHSEnv {
        inherit name targetPkgs;
        runScript = x86.writeScript "xilinx-${name}-runner" (
          configPrefix { }
          + ''
            export LD_LIBRARY_PATH=/lib:$LD_LIBRARY_PATH
            export GDK_BACKEND=x11
            export DISPLAY="''${DISPLAY:-:0}"
            export _JAVA_AWT_WM_NONREPARENTING=1
            export ELECTRON_OZONE_PLATFORM_HINT=x11
            node_dir=$(mktemp -d -t xilinx-node-XXXXXX)
            printf '#!/bin/sh\nexport LD_LIBRARY_PATH=/lib64:$LD_LIBRARY_PATH\nexec /usr/bin/node "$@"\n' \
              > "$node_dir/node"
            chmod +x "$node_dir/node"
            export PATH="$node_dir:$PATH"
            if [[ -d "$INSTALL_DIR/$VERSION/${product}" ]]; then
              exec "$INSTALL_DIR/$VERSION/${product}/bin/${name}" "$@"
            fi
            echo "xilinx: error: ${product} is not installed under $INSTALL_DIR/$VERSION" >&2
            exit 1
          ''
        );
      };
    in
    mkAsahiX86App {
      pname = name;
      package = fhsEnv;
      inherit extraEnv;
      meta = commonMeta // {
        inherit description;
      };
    };
in
{
  xilinx-shell = mkAsahiX86App {
    pname = "xilinx-shell";
    package = x86.buildFHSEnv {
      name = "xilinx-shell";
      inherit targetPkgs;
      runScript = x86.writeScript "xilinx-shell-runner" (
        configPrefix { requireConfig = false; }
        + ''
          cat <<'EOF'
          Xilinx installer shell

          Run the installer downloaded from xilinx.com, then create
          ~/.config/xilinx/nix.sh containing:

            export INSTALL_DIR=/path/to/Xilinx
            export VERSION=2024.2
          EOF
          LD_LIBRARY_PATH=/lib:$LD_LIBRARY_PATH exec bash
        ''
      );
    };
    meta = commonMeta // {
      description = "FEX environment for installing Xilinx tools";
    };
  };

  vivado =
    {
      extraEnv ? { },
    }:
    mkProduct {
      inherit extraEnv;
      product = "Vivado";
      description = "Xilinx HDL synthesis and analysis suite";
    };
  vitis =
    {
      extraEnv ? { },
    }:
    mkProduct {
      inherit extraEnv;
      product = "Vitis";
      description = "Xilinx platform development environment";
    };
  vitis-hls =
    {
      extraEnv ? { },
    }:
    mkProduct {
      inherit extraEnv;
      product = "Vitis_HLS";
      description = "Xilinx high-level synthesis tools";
    };
  model-composer =
    {
      extraEnv ? { },
    }:
    mkProduct {
      inherit extraEnv;
      product = "Model_Composer";
      description = "Xilinx Model Composer launcher";
    };
  xsct =
    {
      extraEnv ? { },
    }:
    mkAsahiX86App {
      pname = "xsct";
      inherit extraEnv;
      package = x86.buildFHSEnv {
        name = "xsct";
        inherit targetPkgs;
        runScript = x86.writeScript "xilinx-xsct-runner" (
          configPrefix { }
          + ''
            export LD_LIBRARY_PATH=/lib:$LD_LIBRARY_PATH
            export XILINX_VIVADO="$INSTALL_DIR/$VERSION/Vivado"
            exec "$INSTALL_DIR/$VERSION/Vivado/bin/xsdb" "$@"
          ''
        );
      };
      meta = commonMeta // {
        description = "Xilinx command-line tool launcher";
      };
    };
}

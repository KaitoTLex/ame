# nix-xilinx's own overlay ignores final/prev and builds from
# nixpkgs.legacyPackages, which has the default config, so host nixpkgs.config
# (the gtk2 handler in hosts/common.nix) never reaches its FHS env and eval
# refuses gtk2. This calls the flake's outputs again with the host's pkgs.
inputs: final: prev:
let
  xilinx = (import "${inputs.nix-xilinx}/flake.nix").outputs {
    self = xilinx;
    nixpkgs = {
      inherit (prev) lib;
      legacyPackages.x86_64-linux = prev;
    };
    inherit (inputs.nix-xilinx.inputs) flake-compat;
  };
in
{
  inherit (xilinx.packages.x86_64-linux)
    xilinx-shell
    vivado
    vlm
    vitis
    vitis_hls
    model_composer
    xsct
    fix-desktop-entries
    ;
}

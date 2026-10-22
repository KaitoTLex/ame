# Home config for futabatlex, the work account on shirakami-fubuki.
# Lighter than home.nix: no personal apps, no hermes gateway (kaitotlex runs that).
{
  pkgs,
  inputs,
  ...
}:
let
  xilinxInstallDir = "/home/futabatlex/xilinx";
  xilinxVersion = "2025.2";
in
{
  imports = [ inputs.hermes-agent.homeManagerModules.default ];

  home.sessionVariables.NIXPKGS_ALLOW_UNFREE = "1";

  # hermes CLI only, with its own state in ~/.hermes. Put the API key in ~/.hermes/.env.
  programs.hermes-agent.enable = true;
  services.hermes-agent = {
    package = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.minimal;
    extraDependencyGroups = [ "anthropic" ];
  };

  home.packages = with pkgs; [
    gcc
    clang-tools
    gnumake
    cmake
    ninja
    pkg-config
    gdb
    # Vivado (imperative install): run AMD's installer inside `xilinx-shell`
    # with Destination = xilinxInstallDir, then `fix-desktop-entries`.
    xilinx-shell
    vivado
    vlm
    xsct
    fix-desktop-entries
  ];

  home.file.".config/xilinx/nix.sh".text = ''
    export INSTALL_DIR=${xilinxInstallDir}
    export VERSION=${xilinxVersion}
  '';

  # For Vivado, which is X11-only.
  systemd.user.services.xwayland-satellite = {
    Unit = {
      Description = "Xwayland outside your Wayland";
      BindsTo = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
    };
    Service = {
      Type = "notify";
      NotifyAccess = "all";
      ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite";
      StandardOutput = "journal";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
  systemd.user.sessionVariables.DISPLAY = ":0";

  programs.git = {
    enable = true;
    settings.url."ssh://git@code.functor.systems/".insteadOf = "https://code.functor.systems/";
  };
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };

  programs.neovim.defaultEditor = true;
  programs.lazygit.enable = true;
  programs.kitty.enable = true;
  programs.firefox.enable = true;
  programs.ripgrep.enable = true;
  programs.fd.enable = true;
  programs.fzf.enable = true;
  programs.btop = {
    enable = true;
    settings.vim_keys = true;
  };
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };
  programs.bash.enable = true;
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    shellAliases = {
      ls = "eza -l --icons=auto";
      sudo = "run0";
    };
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "vi-mode"
      ];
    };
  };

  programs.home-manager.enable = true;
}

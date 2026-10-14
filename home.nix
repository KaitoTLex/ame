{
  pkgs,
  lib,
  inputs,
  osConfig,
  ...
}:
{
  imports = [ ./modules/home/common.nix ];

  home.username = "kaitotlex";
  home.homeDirectory = "/home/kaitotlex";

  # link the configuration file in current directory to the specified location in home directory
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;

  # link all files in `./scripts` to `~/.config/i3/scripts`
  # home.file.".config/i3/scripts" = {
  #   source = ./scripts;
  #   recursive = true;   # link recursively
  #   executable = true;  # make all files executable
  # };

  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
  };
  #programs.rio.enable = true;
  programs.vesktop.enable = true;

  # programs.git:
  # config.credential.helper = "$";
  # config.credential = {
  #   helper = "manager";
  #   "https://github.com".username = "kaitotlex";
  #   credentialStore = "cache";
  # };

  # programs.iamb = {
  #   enable = true;
  #   package = inputs.iamb.packages.${pkgs.stdenv.targetPlatform.system}.default;
  #   settings = {
  #     profiles."matrix.org".user_id = "@kaitotlex:matrix.org";
  #     settings = {
  #       image_preview = { };
  #       notifications = {
  #         enabled = true;
  #         show_message = true;
  #       };
  #     };
  #   };
  # };
  # programs.iamb = {
  #   enable = true;
  #   packages = inputs.iamb.packages.${pkgs.stdenv.targetPlatform.system}.default;
  #   settings = {
  #     profiles."matrix.org" = {
  #       user_id = "@kaitotlex:matrix.org";
  #       style = "restore";
  #     };
  #     settings = {
  #       image_preview = { };
  #       notifications = {
  #         enabled = true;
  #         show_message = true;
  #       };
  #     };
  #   };
  # };
  programs.kitty.settings = {
    font_size = lib.mkForce (if osConfig.networking.hostName == "shirakami-fubuki" then 10 else 12);
    # window_padding_width = "8 8";
    # confirm_os_window_close = -1;
    # enable_audio_bell = "no";
    # allow_remote_control = "yes";
    # scrollback_pager = ''nvim --noplugin -c "set signcolumn=no showtabline=0" -c "silent write! /tmp/kitty_scrollback_buffer | te cat /tmp/kitty_scrollback_buffer - "'';
    # cursor = pkgs.lib.mkForce "#c0caf5";
    # cursor_text_color = pkgs.lib.mkForce "#1a1b26";
    # cursor_trail = 3;
    #background_image = "${inputs.wallpapers}/kitty/moominResized.png";
    # background_image_layout = "cscaled";
    #background_image_linear = "yes";
  };

  # programs.firefox =
  #   let
  #     oldFf =
  #       (import (fetchTarball {
  #         url = "https://github.com/NixOS/nixpkgs/archive/c1e722a6fb379ae79064ddf9c4e0cc580e92a487.tar.gz";
  #         sha256 = "sha256-074m6yha20lv0rjwk6gs93aj6ak7qdj7qzi8k84jzlwj1czcll4i";
  #       }) { localSystem = pkgs.stdenv.hostPlatform; }).firefox-devedition;
  #   in
  #   {
  #     package = pkgs.firefox-devedition;
  #     if pkgs.firefox-devedition.version >= "145.0b9" then oldFf else pkgs.firefox-devedition;
  #   };

  # programs.oh-my-posh = {
  #   enable = true;
  #   enableZshIntegration = true;
  #   enableBashIntegration = true;
  #   useTheme = "catppuccin_macchiato";
  # };

  programs.zsh = {
    shellAliases = {
      nixr = "nh os switch .";
      brokie = "sudo nixos-rebuild switch .#kanade";
      sudo = "run0";
    };
    # interactiveShellInit = ''
    #   fish_vi_key_bindings
    #   set -g fish_greeting
    #   oh-my-posh disable notice
    # '';
    # plugins:
    # {
    #   name = "autopair";
    #   src = pkgs.fetchFromGitHub {
    #     owner = "jorgebucaran";
    #     repo = "zsh-autopair";
    #     rev = "4d1752ff5b39819ab58d7337c69220342e9de0e2";
    #     hash = "sha256-qt3t1iKRRNuiLWiVoiAYOu+";
    #   };
    # }
  };
}

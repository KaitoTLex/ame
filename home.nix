{
  pkgs,
  lib,
  inputs,
  osConfig,
  ...
}:
{
  # Shell, editor, git and CLI tools; shared with the headless hosts.
  imports = [ ./cli.nix ];

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

  # Signing needs the GPG key, which only the desktops have.
  programs.git.signing = {
    signByDefault = true;
    key = "42F52D76F1B15B8D997E2AEE8AB934746F475D0B";
  };

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
  #       image_preview.protocol.type = "kitty";
  #       notifications = {
  #         enabled = true;
  #         show_message = true;
  #       };
  #     };
  #   };
  # };
  programs.kitty = {
    enable = true;
    settings = {
      font_size = lib.mkForce (if osConfig.networking.hostName == "shirakami-fubuki" then 10 else 12);
      # window_padding_width = "8 8";
      # confirm_os_window_close = -1;
      # enable_audio_bell = "no";
      # allow_remote_control = "yes";
      listen_on = "unix:/tmp/kitty";
      # scrollback_pager = ''nvim --noplugin -c "set signcolumn=no showtabline=0" -c "silent write! /tmp/kitty_scrollback_buffer | te cat /tmp/kitty_scrollback_buffer - "'';
      # cursor = pkgs.lib.mkForce "#c0caf5";
      # cursor_text_color = pkgs.lib.mkForce "#1a1b26";
      # cursor_trail = 3;
      #background_image = "${inputs.wallpapers}/kitty/moominResized.png";
      # background_image_layout = "cscaled";
      #background_image_linear = "yes";
    };
  };

  programs.firefox =
    # let
    #   oldFf =
    #     (import (fetchTarball {
    #       url = "https://github.com/NixOS/nixpkgs/archive/c1e722a6fb379ae79064ddf9c4e0cc580e92a487.tar.gz";
    #       sha256 = "sha256-074m6yha20lv0rjwk6gs93aj6ak7qdj7qzi8k84jzlwj1czcll4i";
    #     }) { localSystem = pkgs.stdenv.hostPlatform; }).firefox-devedition;
    # in
    {
      enable = true;
      # package = pkgs.firefox-devedition;
      # if pkgs.firefox-devedition.version >= "145.0b9" then oldFf else pkgs.firefox-devedition;
    };

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  home.stateVersion = "26.05";
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
}

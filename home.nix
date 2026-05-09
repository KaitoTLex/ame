{
  pkgs,
  lib,
  inputs,
  osConfig,
  ...
}:
{
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

  # Hyprland 0.54+ has scrolling layout built-in; the external hyprscrolling plugin is gone
  wayland.windowManager.hyprland.plugins = lib.mkForce [ ];
  # Migrate functorOS's plugin.hyprscrolling config to the new top-level scrolling.* keys
  wayland.windowManager.hyprland.settings.scrolling = {
    explicit_column_widths = "0.333, 0.5, 0.667, 1.0";
    fullscreen_on_one_column = true;
    focus_fit_method = lib.mkForce 1;
  };
  wayland.windowManager.hyprland.settings.input = {
    sensitivity = lib.mkForce 0.0;
    touchpad = lib.mkForce {
      natural_scroll = true;
      scroll_factor = 0.3;
      disable_while_typing = true;
      tap-to-click = false;
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
  };
  #programs.rio.enable = true;
  programs.vesktop.enable = true;

  programs.git = {
    enable = true;
    userName = "KaitoTLex";
    userEmail = "renl@kaitotlex.systems";
    signing = {
      signByDefault = true;
      key = "42F52D76F1B15B8D997E2AEE8AB934746F475D0B";
    };
    # config.credential.helper = "$";
    # config.credential = {
    #   helper = "manager";
    #   "https://github.com".username = "kaitotlex";
    #   credentialStore = "cache";
    # };
  };
  programs.gh = {
    enable = true;
    gitCredentialHelper = {
      enable = true;
    };
  };

  programs.neovim.defaultEditor = true;

  programs.lazygit.enable = true;

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
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
      font_size = lib.mkForce (if osConfig.networking.hostName == "kuroko" then 12 else 15);
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
  programs.ripgrep.enable = true;

  # programs.oh-my-posh = {
  #   enable = true;
  #   enableZshIntegration = true;
  #   enableBashIntegration = true;
  #   useTheme = "catppuccin_macchiato";
  # };

  programs.bash = {
    enable = true;
  };
  programs.zsh = {
    enable = true;
    shellAliases = {
      nixr = "nh os switch .";
      brokie = "sudo nixos-rebuild switch .#kanade";
      ls = "eza -l --icons=auto";
      thefuck = "pay-respects";
    };
    # interactiveShellInit = ''
    #   fish_vi_key_bindings
    #   set -g fish_greeting
    #   oh-my-posh disable notice
    # '';
    oh-my-zsh = {
      # "ohMyZsh" without Home Manager
      enable = true;
      plugins = [
        "git"
        "vi-mode"
      ];
    };
    plugins = [
      # {
      #   name = "autopair";
      #   src = pkgs.fetchFromGitHub {
      #     owner = "jorgebucaran";
      #     repo = "zsh-autopair";
      #     rev = "4d1752ff5b39819ab58d7337c69220342e9de0e2";
      #     hash = "sha256-qt3t1iKRRNuiLWiVoiAYOu+";
      #   };
      # }
      {
        name = "fzf";
        src = pkgs.fetchFromGitHub {
          owner = "junegunn";
          repo = "fzf";
          rev = "e5cd7f0a3a73ef598267c1e9f29b0fe9a80925ab";
          hash = "sha256-cYRA7TCKvfFkWUpI4q1xYR3qzenZvx3cjVSerl0gweU=";
        };
      }
      {
        name = "sponge";
        src = pkgs.fetchFromGitHub {
          owner = "meaningful-ooo";
          repo = "sponge";
          rev = "384299545104d5256648cee9d8b117aaa9a6d7be";
          hash = "sha256-MdcZUDRtNJdiyo2l9o5ma7nAX84xEJbGFhAVhK+Zm1w=";
        };
      }
      {
        name = "done";
        src = pkgs.fetchFromGitHub {
          owner = "franciscolourenco";
          repo = "done";
          rev = "eb32ade85c0f2c68cbfcff3036756bbf27a4f366";
          hash = "sha256-DMIRKRAVOn7YEnuAtz4hIxrU93ULxNoQhW6juxCoh4o=";
        };
      }
    ];
  };

  programs.fd.enable = true;

  programs.btop = {
    enable = true;
    settings = {
      vim_keys = true;
    };
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };

  programs.fzf.enable = true;

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  home.stateVersion = "25.11";
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;

}

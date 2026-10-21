# kaitotlex's terminal environment: shell, editor, git and CLI tools.
# home.nix imports this on the desktops; headless hosts (osaka) use it alone.
{
  pkgs,
  ...
}:
{
  home.sessionVariables.NIXPKGS_ALLOW_UNFREE = "1";

  programs.git = {
    enable = true;
    settings.user = {
      name = "KaitoTLex";
      email = "renl@kaitotlex.systems";
    };
    # code.functor.systems is behind Anubis, which blocks git over https; ssh skips it.
    settings.url."ssh://git@code.functor.systems/".insteadOf = "https://code.functor.systems/";
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
    autosuggestion = {
      enable = true;
    };
    shellAliases = {
      nixr = "nh os switch .";
      brokie = "sudo nixos-rebuild switch .#kanade";
      ls = "eza -l --icons=auto";
      thefuck = "pay-respects";
      sudo = "run0";
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
        name = "fzf-tab";
        src = pkgs.fetchFromGitHub {
          owner = "Aloxaf";
          repo = "fzf-tab";
          rev = "24105b15714bfec37989ed5c5b6e60f572253019";
          hash = "sha256-YhTSu0P7mFlVx1zBvbT0jNstkamcZHhPYJHKMAHgyuM=";
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

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}

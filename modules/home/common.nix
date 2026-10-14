# User environment shared by every host, NixOS and darwin alike.
{ pkgs, ... }:
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
    signing = {
      signByDefault = true;
      key = "42F52D76F1B15B8D997E2AEE8AB934746F475D0B";
    };
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

  programs.kitty = {
    enable = true;
    settings = {
      listen_on = "unix:/tmp/kitty";
    };
  };

  programs.firefox.enable = true;
  programs.ripgrep.enable = true;

  programs.bash = {
    enable = true;
  };
  programs.zsh = {
    enable = true;
    autosuggestion = {
      enable = true;
    };
    shellAliases = {
      ls = "eza -l --icons=auto";
      thefuck = "pay-respects";
    };
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "vi-mode"
      ];
    };
    plugins = [
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

  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}

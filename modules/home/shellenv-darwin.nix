# functorOS's hm/modules/common/shellenv, minus the bits that need a
# functorOS NixOS host (osConfig.functorOS.*) or Linux. Upstream files are
# read straight from the functorOS input so they track it.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  shellenv = "${inputs.functorOS}/hm/modules/common/shellenv";
in
{
  home.file.".essentials" = {
    source = "${inputs.functorOS}/hm/modules/common/essentials";
    recursive = true;
  };

  programs.nushell =
    let
      zoxideInit = pkgs.stdenvNoCC.mkDerivation {
        inherit (pkgs.zoxide) version;
        pname = "zoxide-init";
        nativeBuildInputs = [ pkgs.zoxide ];
        phases = [ "installPhase" ];
        installPhase = ''
          zoxide init nushell >> $out
        '';
      };
    in
    {
      enable = true;
      configFile.source = "${shellenv}/config.nu";
      settings = {
        show_banner = false;
        completions.external = {
          enable = true;
          max_results = 200;
        };
        edit_mode = "vi";
        cursor_shape = {
          emacs = "line";
          vi_insert = "line";
          vi_normal = "block";
        };
      };
      extraConfig = ''
        source "${zoxideInit}"
        def "nu-complete zoxide path" [context: string] {
          let parts = $context | split row " " | skip 1
          {
            options: {
              sort: false
              completion_algorithm: prefix
              positional: false
              case_sensitive: false
            }
            completions: (zoxide query --list --exclude $env.PWD -- ...$parts | lines)
          }
        }

        def --env --wrapped z [...rest: string@"nu-complete zoxide path"] {
          __zoxide_z ...$rest
        }

        $env.config.hooks.command_not_found = source ${pkgs.nix-index-unwrapped}/etc/profile.d/command-not-found.nu
      '';
      plugins = with pkgs.nushellPlugins; [ polars ];
    };

  programs.onibotoke.enable = true;

  programs.git = {
    maintenance.enable = true;
    settings.init.defaultBranch = "main";
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.lazygit.settings.git.paging = {
    colorArg = "always";
    pager = "delta --dark --paging=never";
  };

  programs.bat.enable = true;

  programs.readline = {
    enable = true;
    extraConfig = "set editing-mode vi";
  };

  # functorOS ships its own fish and nushell zoxide integrations
  programs.zoxide = {
    enableFishIntegration = false;
    enableNushellIntegration = false;
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    enableZshIntegration = true;
  };
  home.file.".config/starship.toml".source = "${shellenv}/jetpack.toml";

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config.global.hide_env_diff = true;
  };

  programs.fish = {
    enable = true;
    shellAliases = {
      ls = "eza -l --icons=auto";
    };
    interactiveShellInit = ''
      fish_vi_key_bindings
      set -g fish_greeting
    '';
    plugins = [
      {
        name = "autopair";
        src = pkgs.fishPlugins.autopair.src;
      }
      {
        name = "fzf";
        src = pkgs.fishPlugins.fzf.src;
      }
      {
        name = "done";
        src = pkgs.fishPlugins.done.src;
      }
      {
        name = "sponge";
        src = pkgs.fishPlugins.sponge.src;
      }
      {
        name = "zoxide.fish";
        src = pkgs.fetchFromGitHub {
          owner = "icezyclon";
          repo = "zoxide.fish";
          rev = "a6dabb16dd2de570a2005617ea4510f0beb6dc53";
          hash = "sha256-aGajwgFdB+wtjyryD/EQXSQ3SCFKwDJFjaZjLiJHt3E=";
        };
      }
    ];
  };

  programs.nix-index = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };
  programs.nix-index-database.comma.enable = true;

  programs.btop.settings.theme_background = false;

  programs.eza = {
    enableFishIntegration = true;
    enableNushellIntegration = false;
    git = true;
  };

  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    shellWrapperName = "y";
    plugins = {
      mediainfo = pkgs.fetchFromGitHub {
        owner = "Ape";
        repo = "mediainfo.yazi";
        rev = "c69314e80f5b45fe87a0e06a10d064ed54110439";
        hash = "sha256-8xdBPdKSiwB7iRU8DJdTHY+BjfR9D3FtyVtDL9tNiy4=";
      };
    };
    settings.plugin.prepend_previewers = [
      {
        mime = "{image,audio,video}/*";
        run = "mediainfo";
      }
      {
        mime = "application/x-subrip";
        run = "mediainfo";
      }
    ];
  };

  programs.fastfetch = {
    enable = true;
    settings = builtins.fromJSON (builtins.readFile "${shellenv}/fastfetch/config.json") // {
      logo = {
        height = 18;
        padding.top = 2;
        type = "kitty";
        source = pkgs.runCommand "nixos-logo.png" { } ''
          ${lib.getExe pkgs.imagemagick} ${shellenv}/fastfetch/nixos-logo.png -size 512x512 -fill "#${config.lib.stylix.colors.base0A}" -tint 50 $out
        '';
      };
    };
  };

  home.packages = [ pkgs.git-absorb ];
  home.sessionPath = [ "$HOME/.local/bin" ];

  # not cached for darwin (builds from source); zen is the browser here
  programs.firefox.enable = lib.mkForce false;

  # functorOS's kitty defaults (hm/modules/linux/programs)
  programs.kitty.settings = {
    allow_remote_control = "yes";
    # left option is the physical ctrl and right cmd keys under Karabiner
    # (Alt on kanade); right option still types special characters
    macos_option_as_alt = "left";
    macos_quit_when_last_window_closed = "yes";
  };
  programs.kitty.shellIntegration.enableZshIntegration = true;

  programs.nh = {
    enable = true;
    flake = "${config.home.homeDirectory}/Source/Nix/ame";
  };
  programs.zsh.shellAliases = {
    nixr = "nh darwin switch .";
    brokie = "sudo darwin-rebuild switch --flake .#chisa";
  };

  # commit signing; on NixOS this comes from programs.gnupg.agent
  programs.gpg.enable = true;
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentry.package = pkgs.pinentry_mac;
  };
}

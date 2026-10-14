# kanade's functorOS.theming, applied through stylix directly.
{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  c = config.lib.stylix.colors;
in
{
  stylix = {
    enable = true;
    image = "${inputs.wallpapers}/anime/chisaaura.jpg";
    base16Scheme = ../../scheme/nord.yaml;
    polarity = "dark";
    opacity.popups = 0.9;

    fonts = {
      serif = {
        name = "Noto Serif";
        package = pkgs.noto-fonts;
      };
      sansSerif = {
        name = "Inter";
        package = pkgs.inter;
      };
      emoji = {
        name = "Noto Color Emoji";
        package = pkgs.noto-fonts-color-emoji;
      };
      monospace = {
        name = "CaskaydiaCove Nerd Font";
        package = pkgs.nerd-fonts.caskaydia-cove;
      };
    };
  };

  # functorOS's hm/modules/linux/theming/stylix.nix
  home-manager.sharedModules = [
    {
      stylix.targets = {
        kitty.variant256Colors = true;
        neovim.enable = false;
        starship.enable = false;
      };
    }
    (
      { lib, ... }:
      {
        # stylix has no darwin wallpaper target
        home.activation.wallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${lib.getExe pkgs.desktoppr} all ${config.stylix.image}
        '';
        # delta has no stylix target; reuse the base16 theme the bat target writes
        programs.delta.options.syntax-theme = "base16-stylix";
      }
    )
  ];

  # null leaves macOS's own light/auto setting alone
  system.defaults.NSGlobalDomain.AppleInterfaceStyle =
    if config.stylix.polarity == "dark" then "Dark" else null;

  # niri focus-ring: base0A -> base09 gradient
  services.jankyborders.active_color = lib.mkForce "gradient(top_left=0xff${c.base0A},bottom_right=0xff${c.base09})";
}

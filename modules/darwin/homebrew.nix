# GUI apps with no (working) darwin build in nixpkgs. Homebrew itself is
# pinned through nix-homebrew; taps come from flake inputs.
{ inputs, config, ... }:
{
  nix-homebrew = {
    enable = true;
    user = config.system.primaryUser;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
    };
    mutableTaps = false;
  };

  homebrew = {
    enable = true;
    # keep nix-darwin's tap list in sync with nix-homebrew's
    taps = builtins.attrNames config.nix-homebrew.taps;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      # leave anything installed by hand alone
      cleanup = "none";
    };
    # now-playing for the sketchybar music widget
    brews = [ "media-control" ];
    casks = [
      # rofi window switcher
      "alt-tab"
      # kanade's keyd remap, configured in modules/home/karabiner.nix
      "karabiner-elements"

      "tailscale-app"
      "protonvpn"
      "spotify"
      "signal"
      "element"
      "vesktop"
      "thunderbird"
      "ungoogled-chromium"

      "obsidian"
      "libreoffice"
      "anki"
      "prismlauncher"
      "kicad"
    ];
  };
}

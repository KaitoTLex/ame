# MacBook Air (Apple Silicon), nix-darwin.
{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # julia.withPackages precompiles into $HOME=/homeless-shelter, which is
  # read-only on darwin, so vix1's julia LSP env can't build here
  system = pkgs.stdenv.hostPlatform.system;
  vix = inputs.nixvim.packages.${system}.default.override (prev: {
    # system-theme.lua watches the XDG portal/dconf unconditionally, which
    # throws (and aborts init.lua) where dbus-monitor/dconf don't exist
    luaPath = pkgs.runCommand "vix1-lua" { } ''
      cp -r ${prev.luaPath} $out
      chmod -R u+w $out
      substituteInPlace $out/lua/scripts/system-theme.lua \
        --replace-fail '  watch_portal()' '  if vim.fn.executable("dbus-monitor") == 1 then watch_portal() end' \
        --replace-fail '  watch_dconf()' '  if vim.fn.executable("dconf") == 1 then watch_dconf() end'
    '';
    dependencyOverlays = (prev.dependencyOverlays.${system} or prev.dependencyOverlays or [ ]) ++ [
      (final: prev: { julia = prev.julia // { withPackages = _: prev.julia; }; })
    ];
  });

  # GUI apps that come from homebrew casks on darwin instead
  caskReplaced = [
    "obsidian"
    "prismlauncher"
    "anki"
    "kicad"
    "libreoffice-qt"
    "ungoogled-chromium"
    "proton-vpn"
    "tailscale"
    "tailscale-systray"
  ];
  kaitoPkgs = builtins.filter (
    p: !(builtins.elem (lib.getName p) caskReplaced) && lib.meta.availableOn pkgs.stdenv.hostPlatform p
  ) (import ../../pkgs/common.nix { inherit pkgs; });

  # command line kanade gets from functorOS/NixOS; the GNU userland goes
  # ahead of macOS's BSD tools on PATH so scripts behave the same
  kanadeCli = with pkgs; [
    uutils-coreutils-noprefix
    findutils
    gnugrep
    gnused
    gawk
    gnutar
    diffutils
    which
    less
    gnupatch
    time
    gzip
    bzip2
    xz
    zstd
    zip
    unzip
    p7zip
    wget
    curl
    rsync
    openssh
    nano
    ffmpeg
    imagemagick
    hledger
    khal
    cava
    nurl
    nix-output-monitor
    ragenix
    # for the thefuck alias
    pay-respects
  ];
in
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.stylix.darwinModules.stylix
    inputs.nix-homebrew.darwinModules.nix-homebrew
    ../../modules/darwin/defaults.nix
    ../../modules/darwin/yabai.nix
    ../../modules/darwin/skhd.nix
    ../../modules/darwin/sketchybar.nix
    ../../modules/darwin/homebrew.nix
    ../../modules/darwin/theming.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  # the installer put 2.35 on this machine; don't step back to nixpkgs' default
  nix.package = pkgs.nixVersions.latest;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "kaitotlex"
    ];
  };

  networking.hostName = "chisa";
  networking.computerName = "chisa";
  time.timeZone = "America/New_York";

  system.primaryUser = "kaitotlex";
  users.users.kaitotlex = {
    home = "/Users/kaitotlex";
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];
  environment.systemPackages = [ vix ] ++ kaitoPkgs ++ kanadeCli;
  environment.variables.EDITOR = "nvim";

  security.pam.services.sudo_local.touchIdAuth = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs; };
    users.kaitotlex = {
      imports = [
        inputs.nix-index-database.homeModules.nix-index
        inputs.onibotoke.homeManagerModules.default
        ../../modules/home/common.nix
        ../../modules/home/shellenv-darwin.nix
        ../../modules/home/karabiner.nix
      ];
      home.username = "kaitotlex";
      home.homeDirectory = "/Users/kaitotlex";
    };
  };

  system.stateVersion = 6;
}

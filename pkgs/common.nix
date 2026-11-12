{ pkgs }:

with pkgs;
[
  #productivity
  calcure
  obsidian

  #goonware
  ani-cli
  mpv-unwrapped
  manga-tui
  prismlauncher
  libreoffice-qt
  nicotine-plus

  #music
  #cider

  #opsec
  pass
  tailscale
  tailscale-systray
  aerc
  # openvpn3
  proton-vpn
  # wireguard-ui
  # wireguard-tools

  #contact
  ungoogled-chromium

  #ee
  openhantek6022
  verilator
  gnumake
  cmake
  kicad
  # zed-editor-fhs
  # zed-discord-presence
  jdt-language-server
  # vscodium-fhs
  zulu
  # julia
  # waydroid
  qemu
  ratty
  orca-slicer

  #futaba
  # anki's source build is broken in the pinned nixpkgs: its vendored uv
  # offline cache has no tomlkit, so hatchling cannot resolve from
  # build-system.requires and the build dies with the network disabled.
  # anki-bin is upstream's own prebuilt binary, so it skips that build
  # entirely. Switch back once nixpkgs ships a buildable anki.
  anki-bin
  # ki
  # ankiAddons.review-heatmap
  # ankiAddons.fsrs4anki-helper
  # ankiAddons.ajt-card-management
  # ankiAddons.recolor
  #
  #hamradio
  #rtl-sdr
  #gqrx
  #soapysdr-with-plugins
  openutau
  ticker
  jdk25
]

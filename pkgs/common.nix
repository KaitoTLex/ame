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
  cinny
  ungoogled-chromium

  #ee
  openhantek6022
  verilator
  gnumake
  cmake
  # kicad
  zed-editor-fhs
  zed-discord-presence
  jdt-language-server
  # vscodium-fhs
  zulu
  # julia
  # waydroid
  qemu

  #futaba
  anki
  ki
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
]

{
  pkgs,
  ...
}:
with pkgs;
[
  arduino-cli
  kdePackages.wacomtablet
  sbctl
  kicad
  polychromatic
  openrazer-daemon
  osu-lazer-bin
  tor-browser
  cider-2
  davinci-resolve
  xf86-input-wacom
  tuhi
  libwacom
  opentabletdriver
  lunar-client
  claude-code
  claude-monitor
  libxcb-cursor
]
#formatter."x86_64-linux" = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;

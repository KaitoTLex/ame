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
  davinci-resolve
  xf86-input-wacom
  tuhi
  libwacom
  opentabletdriver
  lunar-client
  claude-code
  claude-monitor
  libxcb-cursor
  msr
  fanctl
  coolercontrol.coolercontrol-gui
  coolercontrol.coolercontrold
  coolercontrol.coolercontrol-ui-data
  # nixpkgs' .desktop handles prusaslicer:// (login callbacks, Printables
  # "Open in PrusaSlicer") but starts a new instance per URL, which drops the
  # login's PKCE verifier. Upstream's own handler hands the URL to the running
  # instance; --single-instance-on-url does that for URLs only. The instance
  # lock is keyed on the canonical argv[0], so Exec needs an absolute path:
  # xdg-open runs the bare name, which keys it on the caller's cwd instead.
  (symlinkJoin {
    inherit (prusa-slicer) name meta;
    paths = [ prusa-slicer ];
    postBuild = ''
      rm $out/share/applications/PrusaSlicer.desktop
      substitute ${prusa-slicer}/share/applications/PrusaSlicer.desktop \
        $out/share/applications/PrusaSlicer.desktop \
        --replace-fail 'Exec=prusa-slicer %U' \
          'Exec=${prusa-slicer}/bin/prusa-slicer --single-instance-on-url %U'
    '';
  })
]
#formatter."x86_64-linux" = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;

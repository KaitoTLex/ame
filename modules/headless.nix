# No monitor, ever: turns the functorOS desktop and everything that only makes
# sense with one (audio, bluetooth, printing, fonts, fcitx5, plymouth) off, and
# keeps boot messages on the console for whoever does plug one in. Goes with
# server.nix on a box nobody sits at.
{ lib, ... }:
{
  functorOS = {
    desktop.enable = false;
    system = {
      audio.enable = false;
      core.bluetooth.enable = false;
      printing.enable = false;
      fonts.enable = false;
    };
  };

  # functorOS turns these on regardless of its own options (localization
  # doesn't check *.input.enable, stylix doesn't check theming.plymouth.enable).
  i18n.inputMethod.enable = lib.mkForce false;
  boot.plymouth.enable = lib.mkForce false;
  boot.consoleLogLevel = lib.mkForce 4;
  boot.initrd.verbose = lib.mkForce true;
}

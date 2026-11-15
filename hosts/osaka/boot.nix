# Kernel and boot loader. Secure Boot is lanzaboote, imported in default.nix.
{ pkgs, lib, ... }:
{
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "k10temp" ];
    kernelParams = [
      "amd_iommu=on"
      "iommu=pt"
      "amd_pstate=active"
    ];
    extraModprobeConfig = ''
      options kvm_amd nested=1
    '';
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = lib.mkForce false;
    };
    # The keys in /var/lib/sbctl aren't enrolled yet: the firmware is still in
    # setup mode, so this boots signed images without enforcing them.
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      configurationLimit = 20;
    };
  };
}

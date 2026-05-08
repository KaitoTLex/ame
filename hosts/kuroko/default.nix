inputs:
{ pkgs, lib, ... }:
let
  laptopDesc = "Sharp Corporation LQ134N1JW52";

  monitorSwitch = pkgs.writeShellApplication {
    name = "kuroko-monitor-switch";
    runtimeInputs = with pkgs; [
      jq
      socat
    ];
    text = ''
      LAPTOP_DESC="${laptopDesc}"

      toggle_display() {
        sleep 0.5
        # count active monitors that are not the built-in laptop display
        EXTERNAL=$(hyprctl monitors -j | jq --arg d "$LAPTOP_DESC" \
          '[.[] | select(.description | contains($d) | not)] | length')
        if [ "$EXTERNAL" -gt 0 ]; then
          hyprctl keyword monitor "desc: $LAPTOP_DESC,disabled"
        else
          hyprctl keyword monitor "desc: $LAPTOP_DESC,preferred,auto,1"
        fi
      }

      toggle_display

      socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" \
        | while IFS= read -r line; do
            case "$line" in
              monitoradded*|monitorremoved*)
                toggle_display
                ;;
            esac
          done
    '';
  };
in
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      timeout = 15;
      systemd-boot.enable = lib.mkForce false;
    };
    kernelPackages = pkgs.linuxPackages_zen;
    kernelModules = [ "uinput" ];
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };

  services.supergfxd.enable = true;
  hardware.opentabletdriver.enable = true;
  hardware.uinput.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    nvidiaSettings = true;
    open = true;
    prime = {
      nvidiaBusId = "PCI:1:0:0";
      amdgpuBusId = "PCI:8:0:0";
      sync.enable = false;
    };
  };

  environment.systemPackages = [ pkgs.supergfxctl ];

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main = {
          capslock = "esc";
          leftalt = "leftcontrol";
          leftcontrol = "leftalt";
          y = "z";
          z = "y";
        };
      };
    };
  };

  services.tlp = {
    enable = true;
    settings = {
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0 = 98;
    };
  };

  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
  };

  functorOS = {
    theming = {
      wallpaper = "${inputs.wallpapers}/anime/plana.jpg";
      polarity = "dark";
      base16Scheme = ../../scheme/plana.yaml;
    };
    system = {
      networking.firewallPresets.vite = false;
      graphics.nvidia.enable = true;
    };
    extras.gaming = {
      enable = true;
      roblox.enable = true;
      utilities.gamemode.enable = true;
    };
  };

  home-manager.users.kaitotlex = {
    wayland.windowManager.hyprland.settings.exec-once = [
      "${monitorSwitch}/bin/kuroko-monitor-switch"
    ];
  };
}

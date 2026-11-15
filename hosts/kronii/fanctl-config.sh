# shellcheck shell=bash
# Writes fanctl's config from the live sysfs tree and fantui's levels file.
# cooling.nix sets JQ, LEVELS, OUT and NVIDIA_TEMP before running this.
#
# Per channel, the levels file says "auto" (leave it on the BIOS curve),
# "curve" (the temperature curve below) or a percentage (fixed). Channels it
# doesn't list get the curve. 20% is the floor, as in fantui: the V100 has no
# fan of its own.
set -eu

level() {
  # shellcheck disable=SC2016
  "$JQ" -r --arg p "$1" '.[$p] // "curve"
    | if . == "auto" or . == "curve" then .
      elif type == "number" then ([[., 20] | max, 100] | min) / 100
      else "curve" end' "$LEVELS" 2>/dev/null || echo curve
}

# temp_input <hwmon name prefix> <label>: the temp*_input behind that label,
# or nothing if the chip or the label isn't there.
temp_input() {
  for h in /sys/class/hwmon/hwmon*; do
    case "$(cat "$h/name")" in "$1"*) ;; *) continue ;; esac
    for l in "$h"/temp*_label; do
      [ -e "$l" ] || continue
      [ "$(cat "$l")" = "$2" ] || continue
      readlink -f "${l%_label}_input"
      return
    done
  done
}

# Which Super I/O channels fanctl drives: everything not on "auto".
curve_fans="" static_fans="" found=0
for h in /sys/class/hwmon/hwmon*; do
  case "$(cat "$h/name")" in nct6*) ;; *) continue ;; esac
  for p in "$h"/pwm[0-9]; do
    [ -e "$p" ] || continue
    found=1
    id="$(basename "$h")_$(basename "$p")"
    case "$(level "$(basename "$p")")" in
      auto) ;;
      curve) curve_fans="$curve_fans $id" ;;
      *) static_fans="$static_fans $id" ;;
    esac
  done
done
if [ "$found" = 0 ]; then
  echo "fanctl: no nct6775 pwm channels under /sys/class/hwmon; is nct6775 loaded?" >&2
  exit 1
fi

# Sensors feeding the curve, each with its own breakpoints (°C:duty). Every
# curve starts at 0 °C: fanctl treats a reading outside the keys as "run at
# 100%", which is the right failsafe above the last key but not below the first.
#   cpu    k10temp Tctl; a Threadripper throttles at 95
#   b60    Arc Pro B60 package; it has a blower, but it breathes case air
#   board  Super I/O SYSTIN, the air inside the case
#   nvidia hottest NVIDIA card (fanctl-nvidia-temp); the V100 slows at ~83
inputs=""
add_input() {
  [ -n "$2" ] && inputs="$inputs $1=$2"
  return 0
}
add_input cpu "$(temp_input k10temp Tctl)"
add_input b60 "$(temp_input xe pkg)"
add_input board "$(temp_input nct6 SYSTIN)"
add_input nvidia "$NVIDIA_TEMP"
keys_for() {
  case "$1" in
    cpu) echo "0:0.2 45:0.2 65:0.45 80:0.75 90:1" ;;
    b60) echo "0:0.2 50:0.2 70:0.5 85:1" ;;
    board) echo "0:0.2 35:0.2 50:0.5 60:1" ;;
    nvidia) echo "0:0.2 45:0.2 60:0.45 72:0.75 80:1" ;;
  esac
}

{
  printf 'interval: 2000\ninputs:\n'
  for i in $inputs; do
    printf '  %s:\n    HwmonSensor:\n      path: %s\n' "${i%%=*}" "${i#*=}"
  done
  printf 'outputs:\n'
  for f in $curve_fans $static_fans; do
    h=${f%%_*} p=${f#*_}
    printf '  %s:\n    PwmFan:\n      path: %s\n      name: %s\n' \
      "$f" "$(readlink -f "/sys/class/hwmon/$h")" "$p"
  done
  printf 'rules:\n'
  if [ -n "$curve_fans" ]; then
    printf '  - outputs:\n'
    for f in $curve_fans; do printf '      - %s\n' "$f"; done
    # Averaged over 5 samples (10 s) so a transient spike doesn't rev the fans.
    printf '    rule:\n      Smooth:\n        samples: 5\n        rule:\n          Maximum:\n            - Static: 0.2\n'
    for i in $inputs; do
      n=${i%%=*}
      printf '            - Curve:\n                input: %s\n                keys:\n' "$n"
      for k in $(keys_for "$n"); do
        printf '                  - input: %s\n                    output: %s\n' "${k%%:*}" "${k#*:}"
      done
    done
  fi
  for f in $static_fans; do
    printf '  - outputs:\n      - %s\n    rule:\n      Static: %s\n' "$f" "$(level "${f#*_}")"
  done
} > "$OUT"

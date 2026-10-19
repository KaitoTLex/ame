# shellcheck shell=bash
# Build the whole fleet on this machine, then push it out over tailscale.
# `flake` and `hosts` are filled in by default.nix.

usage() {
  cat <<EOF
usage: ame <command> [host...]

Builds the ame flake for each machine here, then activates it.

commands:
  build    build only, don't touch any machine
  switch   build, then activate right away
  boot     build, then activate on next reboot
  test     build, then activate without making it the boot default
  update   update flake.lock, then build

hosts: ${hosts[*]} (default: all)

A host that's offline is still built and kept under ~/.cache/ame, so the
next run only has to copy it over.
EOF
}

action=${1:-}
case $action in
  build | switch | boot | test | update) shift ;;
  "" | -h | --help | help)
    usage
    exit 0
    ;;
  *)
    echo "ame: unknown command '$action'" >&2
    usage >&2
    exit 2
    ;;
esac

targets=("$@")
if ((${#targets[@]} == 0)); then
  targets=("${hosts[@]}")
fi
for target in "${targets[@]}"; do
  if [[ " ${hosts[*]} " != *" $target "* ]]; then
    echo "ame: unknown host '$target' (expected one of: ${hosts[*]})" >&2
    exit 2
  fi
done

flake=${AME_FLAKE:-$flake}
cache=${XDG_CACHE_HOME:-$HOME/.cache}/ame
this_host=$(</proc/sys/kernel/hostname)

# BatchMode so a missing key fails fast instead of hanging on a prompt.
# accept-new trusts a host's key the first time it's seen and refuses it if
# it ever changes afterwards.
ssh_opts=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
export NIX_SSHOPTS="${ssh_opts[*]}"

if [[ $action == update ]]; then
  nix flake update --flake "$flake"
  action=build
fi

declare -A result system
failed=0

mkdir -p "$cache"
for host in "${targets[@]}"; do
  echo ":: building $host"
  # The out-link doubles as a gc root, so a build for an offline laptop
  # survives garbage collection until it's deployed.
  if nix build --out-link "$cache/$host" "$flake#nixosConfigurations.$host.config.system.build.toplevel"; then
    system[$host]=$(readlink -f "$cache/$host")
    result[$host]="built"
  else
    result[$host]="build failed"
    failed=1
  fi
done

# `boot` only changes the default generation; switch and test change what's
# running now. Compare against whichever one this action would replace.
if [[ $action == boot ]]; then
  profile=/nix/var/nix/profiles/system
else
  profile=/run/current-system
fi

activate() {
  local host=$1 path=${system[$1]} current

  if [[ $host == "$this_host" ]]; then
    current=$(readlink -f "$profile")
  elif ! current=$(ssh "${ssh_opts[@]}" "root@$host" readlink -f "$profile"); then
    result[$host]="offline, build kept for later"
    return
  fi

  if [[ $current == "$path" ]]; then
    result[$host]="already up to date"
    return
  fi

  echo ":: ${action}ing $host"
  local args=("$action" --no-flake --store-path "$path")
  if [[ $host == "$this_host" ]]; then
    args+=(--elevate run0)
  else
    # Let the target pull whatever it can from the binary cache itself
    # instead of having all of it pushed from here.
    args+=(--target-host "root@$host" --use-substitutes)
  fi

  if nixos-rebuild "${args[@]}"; then
    result[$host]="${action} done"
  else
    result[$host]="${action} failed"
    failed=1
  fi
}

if [[ $action != build ]]; then
  # Other machines first, this one last, so a hiccup here (say, the network
  # restarting) can't cut off a deploy that's still in flight.
  for host in "${targets[@]}"; do
    if [[ -n ${system[$host]:-} && $host != "$this_host" ]]; then
      activate "$host"
    fi
  done
  if [[ -n ${system[$this_host]:-} ]]; then
    activate "$this_host"
  fi
fi

echo
for host in "${targets[@]}"; do
  printf '  %-18s %s\n' "$host" "${result[$host]}"
done

exit "$failed"

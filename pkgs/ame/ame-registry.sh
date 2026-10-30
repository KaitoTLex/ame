# shellcheck shell=bash
#
# `ame fetch` / `ame check` — the generation-registry half of the CLI.
#
# The build/switch/boot/test/update half lives in ame.sh and is unchanged.
# This file is sourced after it when $1 is one of the commands below, so the
# two halves share $flake, $hosts, $cache and the ssh options.
#
# Generations are recorded by the monthly builder (Hoshimachi Suisei's cron
# job) into $registry as one JSON object per line, newest last:
#
#   {"gen":"2026-11","built":"2026-11-30T04:12:09-05:00","rev":"e1a2dc8",
#    "lock":"sha256-...","hosts":{"shirakami-fubuki":"/nix/store/...",...},
#    "digest":"generations/2026-11.md"}
#
# A generation is only appended once every host in it built successfully, so
# `fetch latest` can never land on a half-built set.
#
# $cache is set by the prelude in default.nix (not by ame.sh, which is
# concatenated after this file), so these two are safe to expand here.

registry=$cache/generations.jsonl
digestdir=$cache/generations

# ---------------------------------------------------------------- helpers

die() {
  echo "ame: $*" >&2
  exit 1
}

need_registry() {
  [[ -s $registry ]] || die "no generations recorded yet (expected $registry).
The monthly builder writes it; run 'ame build' + 'ame record' to seed one by hand."
}

# Field out of the last line, or out of the line whose .gen matches $1.
gen_line() {
  local want=${1:-}
  if [[ -z $want || $want == latest ]]; then
    tail -n 1 "$registry"
  else
    # Exact match on the gen label, newest wins if somehow duplicated.
    jq -c --arg g "$want" 'select(.gen == $g)' "$registry" | tail -n 1
  fi
}

# ---------------------------------------------------------------- fetch

cmd_fetch() {
  local want=${1:-latest}
  shift || true
  need_registry

  local line
  line=$(gen_line "$want")
  [[ -n $line ]] || die "no such generation '$want' (try 'ame check gen')"

  local gen this
  gen=$(jq -r '.gen' <<<"$line")
  this=$(</proc/sys/kernel/hostname)

  local path
  path=$(jq -r --arg h "$this" '.hosts[$h] // empty' <<<"$line")
  [[ -n $path ]] || die "generation $gen has no build for this host ($this).
Hosts in it: $(jq -r '.hosts | keys | join(", ")' <<<"$line")"

  echo ":: generation $gen -> $this"
  echo "   $path"

  if [[ -e $path ]]; then
    echo ":: already in the local store"
  else
    # The cache is the point: pull the closure as substituted binaries rather
    # than rebuilding it. The path is signed by the builder's harmonia key,
    # which this host trusts via nix.settings.trusted-public-keys, so no
    # signature override is needed or wanted.
    echo ":: substituting from $cache_url"
    nix copy --from "$cache_url" "$path" \
      || nix-store --realise "$path" \
      || die "could not fetch $path.
Check the cache is up:   ame check cache
Check this host trusts it: nix show-config | grep -E 'substituters|trusted-public-keys'"
  fi

  # Register a gc root so a fetched-but-not-yet-activated generation is not
  # collected out from under the user.
  mkdir -p "$cache/fetched"
  ln -sfn "$path" "$cache/fetched/$gen"

  cat <<EOF

Fetched. It is NOT activated — that needs root:

  sudo $path/bin/switch-to-configuration switch

or, to make it the boot default instead:

  sudo $path/bin/switch-to-configuration boot
EOF
}

# ---------------------------------------------------------------- check

cmd_check_gen() {
  need_registry
  local n
  n=$(wc -l <"$registry")
  echo "$n generation(s) recorded in $registry"
  echo
  printf '  %-9s %-20s %-9s %s\n' GEN BUILT REV HOSTS
  jq -r '
    [ .gen,
      (.built | sub("T"; " ") | sub("[-+]\\d\\d:\\d\\d$"; "")),
      (.rev // "?"),
      (.hosts | keys | join(","))
    ] | @tsv' "$registry" \
    | while IFS=$'\t' read -r g b r h; do
        printf '  %-9s %-20s %-9s %s\n' "$g" "$b" "$r" "$h"
      done
  echo
  echo "Fetch one with: ame fetch <gen>   (or 'ame fetch latest')"
}

cmd_check_current() {
  local this current booted
  this=$(</proc/sys/kernel/hostname)
  current=$(readlink -f /run/current-system)
  booted=$(readlink -f /nix/var/nix/profiles/system)

  echo "host:     $this"
  echo "running:  $current"
  if [[ $booted != "$current" ]]; then
    echo "boot default: $booted"
    echo "          (differs from running — a switch or boot is pending a reboot)"
  fi

  # NixOS records these in the system closure itself, so they describe the
  # build rather than whatever the flake says right now.
  local label ver
  [[ -r $current/nixos-version ]] && ver=$(<"$current/nixos-version")
  [[ -r $current/system-version ]] && label=$(<"$current/system-version")
  [[ -n ${ver:-} ]] && echo "version:  $ver"
  [[ -n ${label:-} ]] && echo "label:    $label"

  # Build date. Store paths all carry mtime=1 for reproducibility, so the
  # store entry itself is useless here; the profile symlink that points at
  # this closure is what actually carries the activation time.
  local when=""
  for link in /nix/var/nix/profiles/system /run/current-system; do
    if [[ -L $link && $(readlink -f "$link") == "$current" ]]; then
      when=$(stat -c %y "$link" 2>/dev/null | cut -d. -f1)
      [[ -n $when ]] && break
    fi
  done
  if [[ -z $when ]]; then
    # Fall back to the newest numbered generation pointing at this closure.
    local g
    g=$(find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' 2>/dev/null \
      | while read -r l; do
          [[ $(readlink -f "$l") == "$current" ]] && stat -c '%Y %n' "$l"
        done | sort -rn | head -1 | cut -d' ' -f1)
    [[ -n $g ]] && when=$(date -d "@$g" '+%Y-%m-%d %H:%M:%S')
  fi
  [[ -n $when ]] && echo "built:    $when" || echo "built:    unknown"

  # Kernel actually running vs the one this closure ships: they differ after
  # a switch without a reboot, which is the single most common "why is this
  # not working" cause.
  echo "kernel:   $(uname -r) (running)"
  local closk=""
  if [[ -e $current/kernel ]]; then
    # /kernel is a symlink into a linux-<ver> store path.
    closk=$(readlink -f "$current/kernel" | sed -n 's|.*/linux-\([0-9][^/]*\)/.*|\1|p' | head -1)
  fi
  if [[ -n $closk ]]; then
    if [[ $(uname -r) == "$closk"* ]]; then
      echo "          $closk (in this closure) — match"
    else
      echo "          $closk (in this closure) — REBOOT PENDING"
    fi
  fi

  # Which recorded generation, if any, this closure corresponds to.
  if [[ -s $registry ]]; then
    local match
    match=$(jq -r --arg h "$this" --arg p "$current" \
      'select(.hosts[$h] == $p) | .gen' "$registry" | tail -n 1)
    if [[ -n $match ]]; then
      echo "generation: $match"
    else
      echo "generation: not from a recorded ame generation (local build?)"
    fi
    local newest
    newest=$(jq -r '.gen' "$registry" | tail -n 1)
    if [[ -n $newest && ${match:-} != "$newest" ]]; then
      echo
      echo "A newer generation is available: $newest"
      echo "  ame fetch latest"
    fi
  fi
}

cmd_check_cache() {
  echo ":: $cache_url"
  if curl -fsS --max-time 10 "$cache_url/nix-cache-info" 2>/dev/null; then
    echo ":: cache is up"
  else
    echo "ame: cache unreachable at $cache_url" >&2
    echo "On the builder, check: systemctl status harmonia" >&2
    return 1
  fi
}

cmd_check_flake() {
  echo ":: $flake"
  if [[ ! -d $flake/.git ]]; then
    echo "   (not a git checkout)"
    return 0
  fi
  git -C "$flake" fetch --quiet origin 2>/dev/null || \
    echo "   (could not reach origin; reporting local state only)"

  local branch ahead behind dirty
  branch=$(git -C "$flake" rev-parse --abbrev-ref HEAD)
  ahead=$(git -C "$flake" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo '?')
  behind=$(git -C "$flake" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo '?')
  dirty=$(git -C "$flake" status --porcelain | wc -l)

  printf '   branch   %s\n' "$branch"
  printf '   ahead    %s commit(s) not pushed\n' "$ahead"
  printf '   behind   %s commit(s) not pulled\n' "$behind"
  printf '   dirty    %s uncommitted path(s)\n' "$dirty"
  [[ $behind != 0 && $behind != '?' ]] && echo "   -> git -C $flake pull --rebase"
  return 0
}

cmd_check() {
  case ${1:-current} in
    current) shift || true; cmd_check_current "$@" ;;
    gen | gens | generations) shift || true; cmd_check_gen "$@" ;;
    cache) shift || true; cmd_check_cache ;;
    flake | repo) shift || true; cmd_check_flake ;;
    all)
      cmd_check_current; echo
      cmd_check_flake;   echo
      cmd_check_cache;   echo
      cmd_check_gen
      ;;
    *) die "unknown check '$1' (current, gen, cache, flake, all)" ;;
  esac
}

# ---------------------------------------------------------------- digest

cmd_digest() {
  need_registry
  local want=${1:-latest} line gen rel
  line=$(gen_line "$want")
  [[ -n $line ]] || die "no such generation '$want'"
  gen=$(jq -r '.gen' <<<"$line")
  rel=$(jq -r '.digest // empty' <<<"$line")
  [[ -n $rel ]] || die "generation $gen has no digest recorded"
  local f=$cache/$rel
  [[ -r $f ]] || die "digest file missing: $f"
  cat "$f"
}

# ---------------------------------------------------------------- record

# Append the generation that was just built. Called by the monthly job after
# every host succeeded; usable by hand to seed the registry.
cmd_record() {
  local gen=${1:-$(date +%Y-%m)}
  local rev lock hosts_json=() h p
  rev=$(git -C "$flake" rev-parse --short HEAD 2>/dev/null || echo unknown)
  lock=$(sha256sum "$flake/flake.lock" 2>/dev/null | cut -c1-16 || echo unknown)

  for h in "${hosts[@]}"; do
    p=$(readlink -f "$cache/$h" 2>/dev/null || true)
    [[ -n $p && -e $p ]] || die "no build for $h at $cache/$h — run 'ame build' first"
    hosts_json+=("$(jq -n --arg k "$h" --arg v "$p" '{($k): $v}')")
  done

  mkdir -p "$digestdir"
  local merged
  merged=$(printf '%s\n' "${hosts_json[@]}" | jq -s 'add')

  jq -c -n \
    --arg gen "$gen" \
    --arg built "$(date --iso-8601=seconds)" \
    --arg rev "$rev" \
    --arg lock "$lock" \
    --argjson hosts "$merged" \
    --arg digest "generations/$gen.md" \
    '{gen:$gen, built:$built, rev:$rev, lock:$lock, hosts:$hosts, digest:$digest}' \
    >>"$registry"

  echo ":: recorded generation $gen"
  echo "   rev $rev, lock $lock"
  jq -r '.hosts | to_entries[] | "   \(.key): \(.value)"' <<<"$(tail -n1 "$registry")"
}

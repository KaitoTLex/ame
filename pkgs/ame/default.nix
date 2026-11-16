{
  lib,
  writeShellApplication,
  coreutils,
  openssh,
  jq,
  curl,
  git,
  installShellFiles,
  runCommand,
  flake,
  hosts,
  # Where `ame fetch` substitutes from. The builder serves its own store over
  # harmonia; the receiving hosts trust the public half of its signing key.
  cacheUrl ? "http://shirakami-fubuki:5000",
}:
let
  ame = writeShellApplication {
    name = "ame";
    # SC2329 "function is never invoked" fires on every cmd_* in
    # ame-registry.sh: they are reached indirectly through `"cmd_$action"` in
    # ame.sh's dispatcher, which whitelists $action first. A file-level
    # shellcheck directive cannot do this because the two files are
    # concatenated, so the directive would land mid-script.
    excludeShellChecks = [ "SC2329" ];
    # nix and nixos-rebuild come from the system on purpose, so they always
    # match the running nix-daemon. The rest are pinned: jq parses the
    # generation registry, curl probes the cache, git reads the flake state.
    runtimeInputs = [
      coreutils
      openssh
      jq
      curl
      git
    ];
    text = ''
      flake=${lib.escapeShellArg flake}
      hosts=(${lib.escapeShellArgs hosts})
      cache_url=${lib.escapeShellArg cacheUrl}

      # Shared state, set here rather than in either .sh file: ame-registry.sh
      # expands $cache at its top level, and it is concatenated first.
      flake=''${AME_FLAKE:-$flake}
      cache=''${XDG_CACHE_HOME:-$HOME/.cache}/ame
      this_host=$(</proc/sys/kernel/hostname)
      mkdir -p "$cache"

      # BatchMode so a missing key fails fast instead of hanging on a prompt.
      # accept-new trusts a host's key the first time it is seen and refuses
      # it if it ever changes afterwards.
      ssh_opts=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
      export NIX_SSHOPTS="''${ssh_opts[*]}"
    ''
    # The registry half defines cmd_fetch / cmd_check / cmd_record /
    # cmd_digest and must be sourced BEFORE ame.sh, whose dispatcher calls
    # them. ame.sh sets up $cache and $flake at the top for the same reason.
    + builtins.readFile ./ame-registry.sh
    + builtins.readFile ./ame.sh;
  };
in
# writeShellApplication has no hook for extra files, so wrap it once more to
# attach the man page. The result keeps `ame` on PATH and adds ame(1).
runCommand "ame"
  {
    nativeBuildInputs = [ installShellFiles ];
    meta = {
      description = "Build, deploy and track NixOS generations across the fleet";
      mainProgram = "ame";
    };
  }
  ''
    mkdir -p $out/bin
    ln -s ${ame}/bin/ame $out/bin/ame
    installManPage ${./ame.1}
  ''

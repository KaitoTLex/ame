# Make nixpkgs' kernel-module aggregator tolerate modules without a
# signing certificate.
#
# Since nixpkgs 6bd7526744 (2026-10-13) `aggregateModules` merges every
# external module's `<name>.ko.cer` into `modules.cer`, and the kernel is
# expected to ship a `modules.cer` of its own. Both steps are unconditional
# `cp`/`cat` and fail the build when a file is missing. Two things in this
# fleet trip it:
#
# - nanashi's pinned 7.1.13 kernel (nixpkgs 2026-09-04) predates
#   `modules.cer` entirely.
# - corecycler's zenpower and ryzen_smu are installed with a bare `install`
#   instead of `modules_install`, so no `.ko.cer` is produced.
#
# The certificates only matter with CONFIG_MODULE_SIG enforcement, which
# neither host uses. Guard both steps; a missing certificate becomes a
# module that is simply not in modules.cer. Remove this overlay when the
# 7.1 pin is gone and corecycler installs through modules_install.
final: prev: {
  aggregateModules =
    modules:
    (prev.aggregateModules modules).overrideAttrs (old: {
      postBuild =
        builtins.replaceStrings
          [
            "cp --no-preserve=mode,ownership --remove-destination \\\n      -- \"$(readlink -f modules.cer)\" modules.cer"
            "| xargs -d'\\n' cat >> modules.cer"
          ]
          [
            "[ -e modules.cer ] && cp --no-preserve=mode,ownership --remove-destination \\\n      -- \"$(readlink -f modules.cer)\" modules.cer || true"
            "| while IFS= read -r f; do [ -e \"$f\" ] && cat \"$f\"; done >> modules.cer"
          ]
          old.postBuild;
    });
}

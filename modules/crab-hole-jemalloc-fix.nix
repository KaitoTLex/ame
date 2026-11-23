# crab-hole (osaka's local DNS sinkhole in hosts/osaka/default.nix) fails to
# build. nixpkgs' Rust setup hook exports a dummy
#   JEMALLOC_OVERRIDE="$sentinel_dir/lib/libjemalloc"
# pointing into a directory that deliberately doesn't exist (the default is
# "use the system jemalloc, don't vendor it"). jemalloc-sys takes
# JEMALLOC_OVERRIDE literally and panics when the path is missing:
#
#   jemalloc-sys-0.5.4+5.3.0-patched/build.rs:106: Path to `jemalloc` in
#   `JEMALLOC_OVERRIDE=nixpkgs.XXXX/use/system/library/lib/libjemalloc` does
#   not exist
#
# The hook only respects a real override when it's already in the environment,
# and rust-jemalloc-sys's own setup hook sets exactly that. Putting it in
# buildInputs does the job (same trick as polars-libgit2-fix.nix). Delete once
# nixpkgs handles jemalloc for crab-hole itself.
final: prev: {
  crab-hole = prev.crab-hole.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ final.rust-jemalloc-sys ];
  });
}

# nu_plugin_polars (pulled in for every user by functorOS's
# hm/modules/common/shellenv: `plugins = with pkgs.nushellPlugins; [ polars ]`)
# fails to build. nixpkgs' Rust infrastructure sets LIBGIT2_NO_VENDOR, so the
# libgit2-sys crate refuses to build its vendored copy and must locate a system
# libgit2 through pkg-config. functorOS's overlay (overlays/default.nix) does
# add libgit2 -- but to nativeCheckInputs, which never reaches the build
# phase's PKG_CONFIG_PATH. The build script therefore panics:
#
#   libgit2-sys-0.18.7+1.9.6/build.rs:100: The environment variable
#   `LIBGIT2_NO_VENDOR` has been set but no compatible system libgit2 could be
#   found. The build is now aborting.
#
# and the failing probe's PKG_CONFIG_PATH shows only openssl/aws-lc/zstd/zlib
# -- precisely the buildInputs -- with no libgit2 anywhere.
#
# nixpkgs' libgit2 is 1.9.7, inside the range libgit2-sys asks for
# (>= 1.9.6, < 1.10.0), so the dependency only needs moving into buildInputs.
# This overlay must apply AFTER functorOS's, hence the mkAfter in common.nix.
# Delete it once functorOS moves libgit2/sqlite to buildInputs itself.
final: prev: {
  nushellPlugins = prev.nushellPlugins // {
    polars = prev.nushellPlugins.polars.overrideAttrs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ [
        final.libgit2
        final.sqlite
      ];
    });
  };
}

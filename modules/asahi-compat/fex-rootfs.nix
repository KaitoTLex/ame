{ lib, fex }:
''
  fex_configured=false
  fex_dir="$HOME/.fex-emu"

  if [[ -d "$fex_dir/RootFS" ]]; then
    for file in "$fex_dir/RootFS"/*; do
      case "$file" in
        *.ero | *.sqsh | *.img) fex_configured=true; break ;;
      esac
      [[ -d "$file" ]] && { fex_configured=true; break; }
    done
  fi

  if [[ "$fex_configured" = false && -f "$fex_dir/Config.json" ]]; then
    if grep -qE '"RootFS"[[:space:]]*:[[:space:]]*"[^"]+"' "$fex_dir/Config.json" 2>/dev/null; then
      fex_configured=true
    fi
  fi

  if [[ "$fex_configured" = false ]]; then
    echo "FEX rootfs not found. Downloading Fedora 43 rootfs (~1.3 GB)..."
    if ! ${lib.getExe' fex "FEXRootFSFetcher"} --assume-yes --distro-name=Fedora \
        --distro-version=43 --distro-list-first --as-is; then
      echo "Automatic download failed. Starting the interactive fetcher..."
      ${lib.getExe' fex "FEXRootFSFetcher"}
    fi
  fi
''

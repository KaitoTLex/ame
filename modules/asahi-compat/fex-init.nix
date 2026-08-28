{
  lib,
  writeShellApplication,
  coreutils,
  util-linux,
  pciutils,
  bash,
  fuse,
  fuse3,
}:
let
  materializedEtcFiles = [
    "host.conf"
    "hosts"
    "localtime"
    "os-release"
    "resolv.conf"
    "nsswitch.conf"
    "group"
    "passwd"
    "machine-id"
  ];
  etcDirectories = [
    "ld.so.conf.d"
    "alternatives"
    "xdg"
    "pulse"
  ];
  etcFiles = [
    "ld.so.cache"
    "ld.so.conf"
    "timezone"
  ];
in
writeShellApplication {
  name = "asahi-fex-init";
  runtimeInputs = [
    coreutils
    util-linux
    pciutils
  ];
  text = ''
    # muvm exposes host runtime paths below /run/muvm-host.
    if [[ -f /etc/NIXOS ]]; then
      ln -sfn /run/muvm-host/run/current-system /run/current-system
      if [[ -d /run/muvm-host/run/opengl-driver ]]; then
        ln -sfn /run/muvm-host/run/opengl-driver /run/opengl-driver
      fi
    fi

    # Steam and vendor tools expect writable FHS paths. Build those paths on
    # the VM's tmpfs and bind them over the read-only host mounts.
    mkdir -p /run/fhs/bin /run/fhs/usr
    cp -a /bin/. /run/fhs/bin/ 2>/dev/null || true
    ln -sf ${bash}/bin/bash /run/fhs/bin/bash
    ln -sf ${bash}/bin/sh /run/fhs/bin/sh

    cp -a /usr/. /run/fhs/usr/ 2>/dev/null || true
    mkdir -p /run/fhs/usr/bin /run/fhs/usr/lib /run/fhs/usr/lib64
    ln -sf ${coreutils}/bin/env /run/fhs/usr/bin/env
    ln -sf ${pciutils}/bin/lspci /run/fhs/usr/bin/lspci

    mkdir -p /run/fhs/usr/share/vulkan
    for directory in /run/opengl-driver/share/vulkan/*/; do
      [[ -d "$directory" ]] && ln -sf "$directory" /run/fhs/usr/share/vulkan/
    done

    layer_dir=/run/fhs/usr/lib/pressure-vessel/overrides/share/vulkan/implicit_layer.d
    mkdir -p "$layer_dir"
    for layer in /home/*/.local/share/vulkan/implicit_layer.d/steam*.json; do
      [[ -f "$layer" ]] && cp "$layer" "$layer_dir/" 2>/dev/null || true
    done

    mount --bind /run/fhs/bin /bin
    mount --bind /run/fhs/usr /usr

    mkdir -p /run/fhs/etc
    cp -a /etc/. /run/fhs/etc/ 2>/dev/null || true
    for file in ${lib.concatStringsSep " " materializedEtcFiles}; do
      if [[ -L "/run/fhs/etc/$file" ]]; then
        target=$(readlink -f "/run/fhs/etc/$file" 2>/dev/null) || continue
        rm -f "/run/fhs/etc/$file"
        if [[ -f "$target" ]]; then
          cp "$target" "/run/fhs/etc/$file"
        elif [[ -d "$target" ]]; then
          mkdir -p "/run/fhs/etc/$file"
          cp -a "$target/." "/run/fhs/etc/$file/"
        fi
      fi
    done
    mkdir -p ${lib.concatMapStringsSep " " (directory: "/run/fhs/etc/${directory}") etcDirectories}
    touch ${lib.concatMapStringsSep " " (file: "/run/fhs/etc/${file}") etcFiles}
    mount --bind /run/fhs/etc /etc

    # FEX mounts its rootfs through fusermount, which must be setuid in the VM.
    mkdir -p /run/wrappers
    mount -t tmpfs -o exec,suid tmpfs /run/wrappers
    mkdir -p /run/wrappers/bin
    cp ${lib.getExe' fuse "fusermount"} /run/wrappers/bin/fusermount
    cp ${lib.getExe' fuse3 "fusermount3"} /run/wrappers/bin/fusermount3
    chown root:root /run/wrappers/bin/fusermount /run/wrappers/bin/fusermount3
    chmod u=srx,g=x,o=x /run/wrappers/bin/fusermount /run/wrappers/bin/fusermount3
  '';
}

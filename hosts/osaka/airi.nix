# airi's Vivado layer (services.airi.vivado) and the Phase 0 bench harness
# (services.airi.bench). The options come from airi's own NixOS module, which
# unpublished.nix imports; this file only configures it.
{ ... }:
{
  services.airi = {
    vivado = {
      enable = true;
      # Install with `airi-xilinx-shell` as kaitotlex (member of `xilinx`).
      installDir = "/opt/Xilinx";
      versions = [ "2026.1" ];
      users = [ "kaitotlex" ];
      hwServer.enable = true;
    };

    bench = {
      enable = true;
      # Vivado runs as the first user; results live in /var/lib/airi-bench.
      users = [ "kaitotlex" ];
      settings = {
        # Must describe the BIOS as currently set (NPS mode, "ACPI SRAT L3
        # Cache as NUMA Domain", SMT, boost). airi-bench refuses to run while
        # this says TODO; update it whenever the BIOS changes.
        # 2026-10-10, observed from sysfs (1 NUMA node, 4 L3 domains, SMT on);
        # confirm against BIOS setup. Variant 1 of 07-bios-variants.
        host.bios = "NPS1 (1 NUMA node), L3-as-NUMA off, SMT on; AMI 0617";
        # One license directory per tier, referenced by path only. Create
        # them and place the license files by hand (or with agenix).
        license.tiers = {
          alveo = "/var/lib/airi/licenses/alveo";
          basic = "/var/lib/airi/licenses/basic";
        };
      };
    };
  };
}

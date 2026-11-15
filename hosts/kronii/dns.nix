# Ad, tracker, malware and adult-site blocking for the tailnet: any device
# whose DNS server is kronii's tailnet address gets it. For every tailnet
# device at once, make that address the only global nameserver in the
# Tailscale admin console, with "Override DNS servers" on. Not on the LAN.
#
# unbound faces clients and crab-hole filters behind it. crab-hole only
# answers plain DNS over UDP, but clients retry truncated answers over TCP
# (and some always use it), so unbound takes both, caches, and asks crab-hole.
let
  crabHole = {
    address = "127.0.0.1";
    port = 5300;
  };
in
{
  services.unbound = {
    enable = true;
    # resolved below already sends kronii's own lookups to 127.0.0.1.
    resolveLocalQueries = false;
    # crab-hole doesn't pass DNSSEC records through, so validating would fail
    # every signed zone. Cloudflare validates upstream.
    enableRootTrustAnchor = false;
    settings = {
      server = {
        interface = [
          "127.0.0.1"
          # kronii's tailnet addresses. ip-freebind binds them even before
          # tailscaled has brought tailscale0 up.
          "100.79.234.116"
          "fd7a:115c:a1e0::842e:ea75"
        ];
        ip-freebind = true;
        access-control = [
          "127.0.0.0/8 allow"
          "100.64.0.0/10 allow"
          "fd7a:115c:a1e0::/48 allow"
        ];
        do-not-query-localhost = false;
        # Blocked names come back NXDOMAIN; don't keep serving a stale block
        # for long after a blocklist update drops it.
        cache-max-negative-ttl = 300;
      };
      forward-zone = [
        {
          name = ".";
          forward-addr = "${crabHole.address}@${toString crabHole.port}";
        }
      ];
    };
  };

  services.crab-hole = {
    enable = true;
    settings = {
      blocklist = {
        include_subdomains = true;
        lists = [
          # StevenBlack unified (ads + malware) plus porn.
          "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts"
          # HaGeZi Multi Pro: ads, tracking, telemetry, phishing. Bare domains;
          # include_subdomains makes them wildcards.
          "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/pro-onlydomains.txt"
          "https://blocklistproject.github.io/Lists/porn.txt"
        ];
      };
      # Only unbound talks to it.
      downstream = [
        {
          protocol = "udp";
          listen = crabHole.address;
          inherit (crabHole) port;
        }
      ];
      # Cloudflare for Families (malware + adult) over DoT, as a second layer.
      upstream.name_servers = [
        {
          socket_addr = "1.1.1.3:853";
          protocol = "tls";
          tls_dns_name = "family.cloudflare-dns.com";
          trust_nx_responses = false;
        }
        {
          socket_addr = "1.0.0.3:853";
          protocol = "tls";
          tls_dns_name = "family.cloudflare-dns.com";
          trust_nx_responses = false;
        }
      ];
    };
  };

  # Send all of kronii's own lookups through the filter too: no DHCP-learned
  # or fallback resolvers.
  services.resolved.settings.Resolve = {
    DNS = [ "127.0.0.1" ];
    Domains = [ "~." ];
    FallbackDNS = [ ];
  };
}

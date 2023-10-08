resource "tailscale_dns_nameservers" "internal" {
  nameservers = [
    local.services.external_dns.ip,
  ]
}

resource "tailscale_dns_preferences" "internal" {
  magic_dns = false
}
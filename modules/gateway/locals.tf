locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      container_images         = var.container_images
      hostname                 = var.hostname
      interfaces               = var.interfaces
      host_netnum              = var.host_netnum
      vrrp_netnum              = var.vrrp_netnum
      static_pod_manifest_path = var.static_pod_manifest_path

      # gateway #
      nftables_name = "gateway_rules"

      # kea #
      dhcp_server_subnet       = var.dhcp_server_subnet
      kea_shared_path          = "/var/lib/kea"
      kea_hooks_libraries_path = "/usr/local/lib/kea/hooks"
      kea_peers                = var.kea_peers
      kea_peer_port            = var.kea_peer_port
      pxeboot_file_name        = var.pxeboot_file_name

      # dns #
      internal_dns_ip             = var.internal_dns_ip
      internal_domain             = var.internal_domain
      upstream_dns_ip             = "9.9.9.9"
      upstream_dns_tls_servername = "dns.quad9.net"

      # keepalived #
      vrrp_master_default_route = {
        table_id       = 250
        table_priority = 32770
      }
      vrrp_slave_default_route = {
        table_id       = 240
        table_priority = 32780
      }
    })
  ]
}
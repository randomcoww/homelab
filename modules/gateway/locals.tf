locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      container_images         = var.container_images
      interfaces               = var.interfaces
      host_netnum              = var.host_netnum
      vrrp_netnum              = var.vrrp_netnum
      static_pod_manifest_path = var.static_pod_manifest_path

      # nftables #
      nftables_name = "gateway_rules"

      # dns #
      internal_domain             = var.internal_domain
      internal_domain_dns_ip      = var.internal_domain_dns_ip
      upstream_dns_ip             = "9.9.9.9"
      upstream_dns_tls_servername = "dns.quad9.net"

      # kea #
      kea_server_name          = var.kea_server_name
      kea_shared_path          = "/var/lib/kea"
      kea_hooks_libraries_path = "/usr/local/lib/kea/hooks"
      kea_peers                = var.kea_peers
      kea_peer_port            = var.kea_peer_port
      pxeboot_file_name        = var.pxeboot_file_name
      dhcp_subnet              = var.dhcp_subnet

      # loadbalancer #
      vrrp_master_default_route = {
        table_id       = 250
        table_priority = 32770
      }
      vrrp_slave_default_route = {
        table_id       = 240
        table_priority = 32780
      }
      dns_internal_port = var.dns_internal_port
      dns_members       = var.dns_members
      nginx_config_path = var.nginx_config_path
    })
  ]
}
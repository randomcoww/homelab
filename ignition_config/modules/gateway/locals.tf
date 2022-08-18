locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      container_images         = var.container_images
      interfaces               = var.interfaces
      host_netnum              = var.host_netnum
      static_pod_manifest_path = var.static_pod_manifest_path

      # nftables #
      nftables_name       = "gateway_rules"
      external_ingress_ip = var.external_ingress_ip
      pod_network_prefix  = var.pod_network_prefix

      # dns #
      upstream_dns_ip             = "9.9.9.9"
      upstream_dns_tls_servername = "dns.quad9.net"

      # loadbalancer #
      vrrp_master_default_route = {
        table_id       = 250
        table_priority = 32770
      }
      vrrp_slave_default_route = {
        table_id       = 240
        table_priority = 32780
      }
      conntrackd_ipv4_ignore = var.conntrackd_ipv4_ignore
      conntrackd_ipv6_ignore = var.conntrackd_ipv6_ignore
      keepalived_config_path = var.keepalived_config_path
      keepalived_services    = var.keepalived_services
      virtual_router_id      = 10
    })
  ]
}
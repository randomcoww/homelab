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
      haproxy_config_path = var.haproxy_config_path
      members             = var.members
    })
  ]
}
locals {
  kea_ha_peers = jsonencode([
    for k, v in var.hosts :
    {
      name          = v.hostname
      role          = lookup(v, "kea_ha_role", "backup")
      url           = "http://${v.networks_by_key.sync.ip}:${var.services.kea.ports.peer}/"
      auto-failover = true
    }
  ])
}

output "templates" {
  value = {
    for host, params in var.hosts :
    host => [
      for template in var.templates :
      templatefile(template, {
        p                          = params
        user                       = var.user
        container_images           = var.container_images
        loadbalancer_pools         = var.loadbalancer_pools
        services                   = var.services
        domains                    = var.domains
        dns_forward_ip             = "9.9.9.9"
        dns_forward_tls_servername = "dns.quad9.net"
        kubelet_path               = "/var/lib/kubelet"
        pod_mount_path             = "/var/lib/kubelet/podconfig"
        kea_path                   = "/var/lib/kea"
        kea_hooks_path             = "/usr/local/lib/kea/hooks"
        kea_ha_peers               = local.kea_ha_peers

        # master route prioirty is slotted in between main and slave
        # when keepalived becomes master on the host
        # priority for both should be greater than 32767 (default)
        slave_default_route_table     = 240
        slave_default_route_priority  = 32780
        master_default_route_table    = 250
        master_default_route_priority = 32770
        vrrp_gateway_id               = 55
        vrrp_dns_id                   = 56
      })
    ]
  }
}

output "addons" {
  value = {
    ## Metallb network
    metallb-network = templatefile(var.addon_templates.metallb-network, {
      loadbalancer_pools = var.loadbalancer_pools
    })
  }
}
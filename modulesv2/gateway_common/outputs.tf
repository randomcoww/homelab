output "templates" {
  value = {
    for k in keys(var.gateway_hosts) :
    k => [
      for template in var.gateway_templates :
      templatefile(template, {
        hostname                   = k
        user                       = var.user
        container_images           = var.container_images
        networks                   = var.networks
        loadbalancer_pools         = var.loadbalancer_pools
        host_network               = var.gateway_hosts[k].host_network
        services                   = var.services
        domains                    = var.domains
        mtu                        = var.mtu
        dns_forward_ip             = "9.9.9.9"
        dns_forward_tls_servername = "dns.quad9.net"

        # Path mounted by kubelet running in container
        kubelet_path = "/var/lib/kubelet"
        # This paths should be visible by kubelet running in the container
        pod_mount_path = "/var/lib/kubelet/podconfig"
        kea_path       = "/var/lib/kea"
        kea_hooks_path = "/usr/local/lib/kea/hooks"
        kea_ha_peers = jsonencode([
          for k in keys(var.gateway_hosts) :
          {
            name = k
            role = var.gateway_hosts[k].kea_ha_role
            url  = "http://${var.gateway_hosts[k].host_network.sync.ip}:${var.services.kea.ports.peer}/"
          }
        ])
      })
    ]
  }
}
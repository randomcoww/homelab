locals {
  params = {
    user             = var.user
    container_images = var.container_images
    services         = var.services
    domains          = var.domains
    kubelet_path     = "/var/lib/kubelet"
    pod_mount_path   = "/var/lib/kubelet/podconfig"
    kea_path         = "/var/lib/kea"
    kea_hooks_path   = "/usr/local/lib/kea/hooks"
    kea_ha_peers = jsonencode([
      for k, v in var.hosts :
      {
        name          = v.hostname
        role          = lookup(v, "kea_ha_role", "backup")
        url           = "http://${v.networks_by_key.internal.ip}:${var.services.kea.ports.peer}/"
        auto-failover = true
      }
    ])

    vrrp_id           = 50
    dns_redirect_port = 55353
  }
}

output "ignition" {
  value = {
    for host, params in var.hosts :
    host => [
      for f in fileset(".", "${path.module}/templates/ignition/*") :
      templatefile(f, merge(local.params, {
        p = params
      }))
    ]
  }
}
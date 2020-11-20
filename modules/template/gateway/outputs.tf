locals {
  params = {
    user               = var.user
    container_images   = var.container_images
    loadbalancer_pools = var.loadbalancer_pools
    services           = var.services
    domains            = var.domains
    kubelet_path       = "/var/lib/kubelet"
    pod_mount_path     = "/var/lib/kubelet/podconfig"
    kea_path           = "/var/lib/kea"
    kea_hooks_path     = "/usr/local/lib/kea/hooks"
    kea_ha_peers = jsonencode([
      for k, v in var.hosts :
      {
        name          = v.hostname
        role          = lookup(v, "kea_ha_role", "backup")
        url           = "http://${v.networks_by_key.sync.ip}:${var.services.kea.ports.peer}/"
        auto-failover = true
      }
    ])

    # master route prioirty is slotted in between main and slave
    # when keepalived becomes master on the host
    # priority for both should be greater than 32767 (default)
    slave_default_route_table     = 240
    slave_default_route_priority  = 32780
    master_default_route_table    = 250
    master_default_route_priority = 32770
    vrrp_id_base                  = 50
    dns_redirect_port             = 55353
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

output "kubernetes" {
  value = [
    for f in fileset(".", "${path.module}/templates/kubernetes/*") :
    templatefile(f, local.params)
  ]
}
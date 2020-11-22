locals {
  params = {
    user               = var.user
    container_images   = var.container_images
    loadbalancer_pools = var.loadbalancer_pools
    services           = var.services
    domains            = var.domains
    kubelet_path       = "/var/lib/kubelet"
    pod_mount_path     = "/var/lib/kubelet/podconfig"

    # master route prioirty is slotted in between main and slave
    # when keepalived becomes master on the host
    # priority for both should be greater than 32767 (default)
    slave_default_route_table     = 240
    slave_default_route_priority  = 32780
    master_default_route_table    = 250
    master_default_route_priority = 32770
    vrrp_id                       = 60
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
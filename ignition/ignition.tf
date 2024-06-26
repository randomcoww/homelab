locals {
  modules_enabled = [
    module.base,
    module.systemd-networkd,
    module.network-manager,
    module.upstream-dns,
    module.gateway,
    module.vrrp,
    module.disks,
    module.etcd,
    module.kubernetes-master,
    module.kubernetes-worker,
    module.nvidia-container,
    module.server,
    module.client,
    module.desktop-environment,
    module.sunshine,
    module.remote,
  ]
}

data "ct_config" "ignition" {
  for_each = {
    for host_key in keys(local.hosts) :
    host_key => flatten([
      for m in local.modules_enabled :
      try(m[host_key].ignition_snippets, [])
    ])
  }
  content = yamlencode({
    variant = "fcos"
    version = local.ignition_version
  })
  strict   = true
  snippets = sort(each.value)
}
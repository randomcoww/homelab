locals {
  ignition_snippets = {
    for host_key in keys(local.hosts) :
    host_key => sort(flatten([
      for m in [
        module.base,
        module.systemd-networkd,
        module.upstream-dns,
        module.gateway,
        module.disks,
        module.etcd,
        module.kubernetes-master,
        module.kubernetes-worker,
        module.server,
      ] :
      try(m[host_key].ignition_snippets, [])
    ]))
  }
}

data "ct_config" "ignition" {
  for_each = local.ignition_snippets

  content = yamlencode({
    variant = "fcos"
    version = local.butane_version
  })
  pretty_print = false
  strict       = true
  snippets     = each.value
}
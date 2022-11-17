# combine and render a single ignition file #
data "ct_config" "ignition" {
  for_each = {
    for host_key in keys(local.hosts) :
    host_key => flatten([
      try(module.ignition-base[host_key].ignition_snippets, []),
      try(module.ignition-systemd-networkd[host_key].ignition_snippets, []),
      try(module.ignition-network-manager[host_key].ignition_snippets, []),
      try(module.ignition-gateway[host_key].ignition_snippets, []),
      try(module.ignition-vrrp[host_key].ignition_snippets, []),
      try(module.ignition-disks[host_key].ignition_snippets, []),
      try(module.ignition-kubelet-base[host_key].ignition_snippets, []),
      try(module.ignition-etcd[host_key].ignition_snippets, []),
      try(module.ignition-kubernetes-master[host_key].ignition_snippets, []),
      try(module.ignition-kubernetes-worker[host_key].ignition_snippets, []),
      try(module.ignition-ssh-server[host_key].ignition_snippets, []),
      try(module.ignition-desktop[host_key].ignition_snippets, []),
    ])
  }
  content  = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict   = true
  snippets = each.value
}

resource "local_file" "ignition" {
  for_each = local.hosts

  content  = data.ct_config.ignition[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}
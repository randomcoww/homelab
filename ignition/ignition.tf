locals {
  modules_enabled = [
    module.base,
    module.systemd-networkd,
    module.upstream-dns,
    module.gateway,
    module.disks,
    module.etcd,
    module.kubernetes-master,
    module.kubernetes-worker,
    module.server,
    module.client,
  ]

  prometheus_targets = merge([
    for i, m in local.modules_enabled :
    transpose(merge(flatten([
      for _, host in m :
      [
        for _, job in try(host.prometheus_jobs, []) :
        {
          for _, t in job.targets :
          t => [job.params.job_name]
        }
      ]
    ])...))
  ]...)
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
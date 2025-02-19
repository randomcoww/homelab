output "ignition" {
  value = {
    for host_key, content in data.ct_config.ignition :
    host_key => content.rendered
  }
  sensitive = true
}

# Write local files so that PXE update can work during outage
resource "local_file" "ignition" {
  for_each = local.hosts

  content  = data.ct_config.ignition[each.key].rendered
  filename = "${path.module}/output/ignition/${each.key}.ign"
}

output "podlist" {
  value = {
    for host_key in keys(local.hosts) :
    host_key => yamlencode({
      apiVersion = "v1"
      kind       = "PodList"
      items = flatten([
        for _, m in local.modules_enabled :
        [
          for pod in try(m[host_key].pod_manifests, []) :
          yamldecode(pod)
        ]
      ])
    })
  }
  sensitive = true
}

output "prometheus_jobs" {
  value = merge([
    for i, m in local.modules_enabled :
    merge(flatten([
      for _, host in m :
      {
        for _, job in try(host.prometheus_jobs, []) :
        job.job_name => {
          targets = local.prometheus_targets[job.job_name]
          params = {
            for k, v in job :
            k => v if k != "targets"
          }
        }
      }
    ])...)
  ]...)
}
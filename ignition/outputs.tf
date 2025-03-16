output "ignition" {
  value = {
    for host_key, content in data.ct_config.ignition :
    host_key => content.rendered
  }
  sensitive = true
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
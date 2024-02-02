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

output "static_pods" {
  value = {
    for host_key, pod_manifests in local.pod_manifests :
    host_key => chomp(join("---\n", pod_manifests)) if length(pod_manifests) > 0
  }
  sensitive = true
}
output "ignition_snippets" {
  value = local.ignition_snippets
}

output "pod_manifests" {
  value = local.pod_manifests
}

output "remote_files" {
  value     = local.remote_files
  sensitive = true
}
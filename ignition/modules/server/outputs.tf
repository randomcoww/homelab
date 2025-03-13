output "ignition_snippets" {
  value = local.ignition_snippets
}

output "remote_files" {
  value     = local.remote_files
  sensitive = true
}
output "ignition_snippets" {
  value = local.module_ignition_snippets
}

output "local_client_endpoint" {
  value = "https://127.0.0.1:${var.etcd_client_port}"
}
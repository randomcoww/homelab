output "ignition_snippets" {
  value = local.module_ignition_snippets
}

output "client_endpoint" {
  value = "https://${cidrhost(var.network_prefix, var.host_netnum)}:${var.etcd_client_port}"
}

output "local_client_endpoint" {
  value = "https://127.0.0.1:${var.etcd_client_port}"
}
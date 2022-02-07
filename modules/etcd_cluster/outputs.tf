output "ca" {
  value = local.ca
}

output "peer_ca" {
  value = local.peer_ca
}

output "certs" {
  value = local.certs
}

output "cluster_endpoints" {
  value = local.cluster_endpoints
}

output "member_template_params" {
  value = {
    for host_key, host in var.cluster_hosts :
    host_key => merge(host, {
      cluster_token     = var.cluster_token
      cluster_endpoints = local.cluster_endpoints
      initial_cluster   = local.initial_cluster

      client_url       = "https://${host.ip}:${host.client_port}"
      local_client_url = "https://127.0.0.1:${host.client_port}"
      peer_url         = "https://${host.ip}:${host.peer_port}"

      aws_user_access = local.aws_user_access
      s3_backup_path  = local.s3_backup_path
      aws_region      = var.aws_region
    })
  }
}
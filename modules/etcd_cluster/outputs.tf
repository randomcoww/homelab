output "ca" {
  value = local.ca
}

output "peer_ca" {
  value = local.peer_ca
}

output "certs" {
  value = local.certs
}

output "cluster" {
  value = {
    cluster_token     = var.cluster_token
    cluster_endpoints = local.cluster_endpoints
    initial_cluster   = local.initial_cluster
  }
}

output "backup" {
  value = {
    aws_access_key_id     = aws_iam_access_key.s3-backup.id
    aws_access_key_secret = aws_iam_access_key.s3-backup.secret
    s3_backup_path        = local.s3_backup_path
    aws_region            = var.aws_region
  }
}

output "members" {
  value = {
    for host_key, host in var.cluster_hosts :
    host_key => merge(host, {
      initial_advertise_peer_urls = ["https://${host.ip}:${host.peer_port}"]
      listen_peer_urls            = ["https://${host.ip}:${host.peer_port}"]
      advertise_client_urls       = ["https://${host.ip}:${host.client_port}"]
      listen_client_urls          = ["https://127.0.0.1:${host.client_port}", "https://${host.ip}:${host.client_port}"]
    })
  }
}
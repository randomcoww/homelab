output "cluster_name" {
  value = var.cluster_name
}

output "apiserver_endpoint" {
  value = "https://${var.services.kubernetes_apiserver.vip}:${var.services.kubernetes_apiserver.ports.secure}"
}

output "kubernetes_ca_pem" {
  value = tls_self_signed_cert.kubernetes-ca.cert_pem
}

output "kubernetes_cert_pem" {
  value = tls_locally_signed_cert.kubernetes-client.cert_pem
}

output "kubernetes_private_key_pem" {
  value = tls_private_key.kubernetes-client.private_key_pem
}

output "controller_params" {
  value = {
    for k in keys(var.controller_hosts) :
    k => {
      hostname           = k
      user               = var.user
      ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"
      mtu                = var.mtu
      cluster_name       = var.cluster_name

      container_images = var.container_images
      networks         = var.networks
      host_network     = var.controller_hosts[k].network
      services         = var.services

      etcd_cluster_token    = var.cluster_name
      s3_etcd_backup_path   = "${var.s3_etcd_backup_bucket}/${var.cluster_name}"
      aws_region            = var.s3_backup_aws_region
      aws_access_key_id     = aws_iam_access_key.s3-etcd-backup.id
      aws_secret_access_key = aws_iam_access_key.s3-etcd-backup.secret
      etcd_initial_cluster = join(",", [
        for k in keys(var.controller_hosts) :
        "${k}=https://${var.controller_hosts[k].network.store.ip}:${var.services.etcd.ports.peer}"
      ])
      etcd_endpoints = join(",", [
        for k in keys(var.controller_hosts) :
        "https://${var.controller_hosts[k].network.store.ip}:${var.services.etcd.ports.client}"
      ])
      etcd_local_endpoint      = "https://127.0.0.1:${var.services.etcd.ports.client}"
      apiserver_local_endpoint = "https://127.0.0.1:${var.services.kubernetes_apiserver.ports.secure}"
      kubelet_path             = "/var/lib/kubelet"

      tls_kubernetes_ca          = replace(tls_self_signed_cert.kubernetes-ca.cert_pem, "\n", "\\n")
      tls_kubernetes_ca_key      = replace(tls_private_key.kubernetes-ca.private_key_pem, "\n", "\\n")
      tls_kubernetes             = replace(tls_locally_signed_cert.kubernetes[k].cert_pem, "\n", "\\n")
      tls_kubernetes_key         = replace(tls_private_key.kubernetes[k].private_key_pem, "\n", "\\n")
      tls_controller_manager     = replace(tls_locally_signed_cert.controller-manager.cert_pem, "\n", "\\n")
      tls_controller_manager_key = replace(tls_private_key.controller-manager.private_key_pem, "\n", "\\n")
      tls_scheduler              = replace(tls_locally_signed_cert.scheduler.cert_pem, "\n", "\\n")
      tls_scheduler_key          = replace(tls_private_key.scheduler.private_key_pem, "\n", "\\n")

      tls_service_account     = replace(tls_private_key.service-account.public_key_pem, "\n", "\\n")
      tls_service_account_key = replace(tls_private_key.service-account.private_key_pem, "\n", "\\n")

      tls_etcd_ca         = replace(tls_self_signed_cert.etcd-ca.cert_pem, "\n", "\\n")
      tls_etcd            = replace(tls_locally_signed_cert.etcd[k].cert_pem, "\n", "\\n")
      tls_etcd_key        = replace(tls_private_key.etcd[k].private_key_pem, "\n", "\\n")
      tls_etcd_client     = replace(tls_locally_signed_cert.etcd-client[k].cert_pem, "\n", "\\n")
      tls_etcd_client_key = replace(tls_private_key.etcd-client[k].private_key_pem, "\n", "\\n")
    }
  }
}

output "worker_params" {
  value = {
    for k in keys(var.worker_hosts) :
    k => {
      hostname           = k
      user               = var.user
      ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"
      mtu                = var.mtu
      cluster_name       = var.cluster_name

      container_images = var.container_images
      networks         = var.networks
      host_network     = var.worker_hosts[k].network
      host_disks       = var.worker_hosts[k].disks
      services         = var.services
      domains          = var.domains

      apiserver_endpoint = "https://${var.services.kubernetes_apiserver.vip}:${var.services.kubernetes_apiserver.ports.secure}"
      kubelet_path       = "/var/lib/kubelet"

      tls_kubernetes_ca = replace(tls_self_signed_cert.kubernetes-ca.cert_pem, "\n", "\\n")
      tls_bootstrap     = replace(tls_locally_signed_cert.bootstrap.cert_pem, "\n", "\\n")
      tls_bootstrap_key = replace(tls_private_key.bootstrap.private_key_pem, "\n", "\\n")
    }
  }
}
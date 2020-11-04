locals {
  params = {
    user                     = var.user
    domains = var.domains
    cluster_name             = var.cluster_name
    container_images         = var.container_images
    networks                 = var.networks
    services                 = var.services
    etcd_cluster_token       = var.cluster_name
    s3_etcd_backup_path      = "${var.s3_etcd_backup_bucket}/${var.cluster_name}"
    aws_region               = var.aws_region
    aws_access_key_id        = aws_iam_access_key.s3-etcd-backup.id
    aws_secret_access_key    = aws_iam_access_key.s3-etcd-backup.secret
    etcd_local_endpoint      = "https://127.0.0.1:${var.services.etcd.ports.client}"
    apiserver_local_endpoint = "https://127.0.0.1:${var.services.kubernetes_apiserver.ports.secure}"
    apiserver_endpoint       = "https://${var.services.kubernetes_apiserver.vip}:${var.services.kubernetes_apiserver.ports.secure}"
    kubelet_path             = "/var/lib/kubelet"
    pod_mount_path           = "/var/lib/kubelet/podconfig"
    controller_mount_path    = "/var/lib/kubelet/controller"
    vrrp_id                  = 70
    etcd_initial_cluster = join(",", [
      for k, v in var.controller_hosts :
      "${v.hostname}=https://${v.networks_by_key.main.ip}:${var.services.etcd.ports.peer}"
    ])
    etcd_endpoints = join(",", [
      for k, v in var.controller_hosts :
      "https://${v.networks_by_key.main.ip}:${var.services.etcd.ports.client}"
    ])
  }
}

output "cluster_endpoint" {
  value = {
    cluster_name               = var.cluster_name
    apiserver_endpoint         = "https://${var.services.kubernetes_apiserver.vip}:${var.services.kubernetes_apiserver.ports.secure}"
    kubernetes_ca_pem          = tls_self_signed_cert.kubernetes-ca.cert_pem
    kubernetes_cert_pem        = tls_locally_signed_cert.kubernetes-client.cert_pem
    kubernetes_private_key_pem = tls_private_key.kubernetes-client.private_key_pem
  }
}

output "ignition_controller" {
  value = {
    for host, params in var.controller_hosts :
    host => [
      for f in fileset(".", "${path.module}/templates/ignition_controller/*") :
      templatefile(f, merge(local.params, {
        p                          = params
        tls_kubernetes_ca          = replace(tls_self_signed_cert.kubernetes-ca.cert_pem, "\n", "\\n")
        tls_kubernetes_ca_key      = replace(tls_private_key.kubernetes-ca.private_key_pem, "\n", "\\n")
        tls_kubernetes             = replace(tls_locally_signed_cert.kubernetes[host].cert_pem, "\n", "\\n")
        tls_kubernetes_key         = replace(tls_private_key.kubernetes[host].private_key_pem, "\n", "\\n")
        tls_controller_manager     = replace(tls_locally_signed_cert.controller-manager.cert_pem, "\n", "\\n")
        tls_controller_manager_key = replace(tls_private_key.controller-manager.private_key_pem, "\n", "\\n")
        tls_scheduler              = replace(tls_locally_signed_cert.scheduler.cert_pem, "\n", "\\n")
        tls_scheduler_key          = replace(tls_private_key.scheduler.private_key_pem, "\n", "\\n")
        tls_service_account        = replace(tls_private_key.service-account.public_key_pem, "\n", "\\n")
        tls_service_account_key    = replace(tls_private_key.service-account.private_key_pem, "\n", "\\n")
        tls_etcd_ca                = replace(tls_self_signed_cert.etcd-ca.cert_pem, "\n", "\\n")
        tls_etcd                   = replace(tls_locally_signed_cert.etcd[host].cert_pem, "\n", "\\n")
        tls_etcd_key               = replace(tls_private_key.etcd[host].private_key_pem, "\n", "\\n")
        tls_etcd_client            = replace(tls_locally_signed_cert.etcd-client[host].cert_pem, "\n", "\\n")
        tls_etcd_client_key        = replace(tls_private_key.etcd-client[host].private_key_pem, "\n", "\\n")
      }))
    ]
  }
}

output "ignition_worker" {
  value = {
    for host, params in var.worker_hosts :
    host => [
      for f in fileset(".", "${path.module}/templates/ignition_worker/*") :
      templatefile(f, merge(local.params, {
        p                 = params
        tls_kubernetes_ca = replace(tls_self_signed_cert.kubernetes-ca.cert_pem, "\n", "\\n")
        tls_bootstrap     = replace(tls_locally_signed_cert.bootstrap.cert_pem, "\n", "\\n")
        tls_bootstrap_key = replace(tls_private_key.bootstrap.private_key_pem, "\n", "\\n")
      }))
    ]
  }
}

output "kubernetes" {
  value = [
    for f in fileset(".", "${path.module}/templates/kubernetes/*") :
    templatefile(f, local.params)
  ]
}
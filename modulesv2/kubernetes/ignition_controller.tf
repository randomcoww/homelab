##
## provisioner ignition renderer
##
resource "matchbox_group" "ign-controller" {
  for_each = var.controller_hosts

  profile = matchbox_profile.ign-profile.name
  name    = each.key
  selector = {
    mac = each.value.network.int_mac
  }

  metadata = {
    config = templatefile("${path.module}/../../templates/ignition/controller.ign.tmpl", {
      hostname           = each.key
      user               = var.user
      ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"
      mtu                = var.mtu
      cluster_name       = var.cluster_name

      container_images = var.container_images
      networks         = var.networks
      host_network     = each.value.network
      services         = var.services

      etcd_cluster_token    = var.cluster_name
      s3_etcd_backup_path   = "${var.s3_etcd_backup_bucket}/${var.cluster_name}"
      aws_region            = var.s3_backup_aws_region
      aws_access_key_id     = aws_iam_access_key.s3-etcd-backup.id
      aws_secret_access_key = aws_iam_access_key.s3-etcd-backup.secret
      etcd_initial_cluster = join(",", [
        for k in keys(var.controller_hosts) :
        "${k}=https://${var.controller_hosts[k].network.store_ip}:${var.services.etcd.ports.peer}"
      ])
      etcd_endpoints = join(",", [
        for k in keys(var.controller_hosts) :
        "https://${var.controller_hosts[k].network.store_ip}:${var.services.etcd.ports.client}"
      ])
      etcd_local_endpoint      = "https://127.0.0.1:${var.services.etcd.ports.client}"
      apiserver_local_endpoint = "https://127.0.0.1:${var.services.kubernetes_apiserver.ports.secure}"
      kubelet_path             = "/var/lib/kubelet"

      tls_kubernetes_ca          = replace(tls_self_signed_cert.kubernetes-ca.cert_pem, "\n", "\\n")
      tls_kubernetes_ca_key      = replace(tls_private_key.kubernetes-ca.private_key_pem, "\n", "\\n")
      tls_kubernetes             = replace(tls_locally_signed_cert.kubernetes[each.key].cert_pem, "\n", "\\n")
      tls_kubernetes_key         = replace(tls_private_key.kubernetes[each.key].private_key_pem, "\n", "\\n")
      tls_controller_manager     = replace(tls_locally_signed_cert.controller-manager.cert_pem, "\n", "\\n")
      tls_controller_manager_key = replace(tls_private_key.controller-manager.private_key_pem, "\n", "\\n")
      tls_scheduler              = replace(tls_locally_signed_cert.scheduler.cert_pem, "\n", "\\n")
      tls_scheduler_key          = replace(tls_private_key.scheduler.private_key_pem, "\n", "\\n")

      tls_service_account     = replace(tls_private_key.service-account.public_key_pem, "\n", "\\n")
      tls_service_account_key = replace(tls_private_key.service-account.private_key_pem, "\n", "\\n")

      tls_etcd_ca         = replace(tls_self_signed_cert.etcd-ca.cert_pem, "\n", "\\n")
      tls_etcd            = replace(tls_locally_signed_cert.etcd[each.key].cert_pem, "\n", "\\n")
      tls_etcd_key        = replace(tls_private_key.etcd[each.key].private_key_pem, "\n", "\\n")
      tls_etcd_client     = replace(tls_locally_signed_cert.etcd-client[each.key].cert_pem, "\n", "\\n")
      tls_etcd_client_key = replace(tls_private_key.etcd-client[each.key].private_key_pem, "\n", "\\n")
    })
  }
}
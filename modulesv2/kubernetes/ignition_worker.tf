##
## worker ignition renderer
##
resource "matchbox_group" "ign-worker" {
  for_each = var.worker_hosts

  profile = matchbox_profile.ign-profile.name
  name    = each.key
  selector = {
    mac = each.value.network.int_mac
  }

  metadata = {
    config = templatefile("${path.module}/../../templates/ignition/worker.ign.tmpl", {
      hostname           = each.key
      user               = var.user
      ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"
      mtu                = var.mtu
      cluster_name       = var.cluster_name

      container_images = var.container_images
      networks         = var.networks
      host_network     = each.value.network
      services         = var.services
      domains          = var.domains

      apiserver_endpoint = "https://${var.apiserver_vip}:${var.services.kubernetes_apiserver.ports.secure}"
      kubelet_path       = "/var/lib/kubelet"

      tls_kubernetes_ca = replace(tls_self_signed_cert.kubernetes-ca.cert_pem, "\n", "\\n")
      tls_bootstrap     = replace(tls_locally_signed_cert.bootstrap.cert_pem, "\n", "\\n")
      tls_bootstrap_key = replace(tls_private_key.bootstrap.private_key_pem, "\n", "\\n")
    })
  }
}
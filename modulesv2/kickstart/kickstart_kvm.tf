##
## KVM (HW) kickstart renderer
##
resource "random_password" "ks-kvm" {
  length  = 30
  special = false
}

resource "matchbox_group" "ks-kvm" {
  profile = matchbox_profile.generic-profile.name
  name    = "kvm"
  selector = {
    ks = "kvm"
  }
  metadata = {
    config = templatefile("${path.module}/../../templates/kickstart/kvm.ks.tmpl", {
      user               = var.user
      password           = random_password.ks-kvm.result
      ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"
      hosts              = var.kvm_hosts
      mtu                = var.mtu

      vlans = [
        for k in keys(var.networks) :
        k
        if lookup(var.networks[k], "id", null) != null
      ]
      internal_networks = {
        int = {
          if = var.networks.int.br_if
          ip = var.services.renderer.vip
        }
      }

      networks                 = var.networks
      services                 = var.services
      certs_path               = "/etc/ssl/certs"
      matchbox_url             = "https://github.com/poseidon/matchbox/releases/download/v0.8.3/matchbox-v0.8.3-linux-amd64.tar.gz"
      matchbox_data_path       = "/var/lib/matchbox/data"
      matchbox_assets_path     = "/var/lib/matchbox/assets"
      tls_matchbox_ca          = chomp(tls_self_signed_cert.matchbox-ca.cert_pem)
      tls_matchbox             = chomp(tls_locally_signed_cert.matchbox.cert_pem)
      tls_matchbox_key         = chomp(tls_private_key.matchbox.private_key_pem)
      container_linux_base_url = "https://edge.release.flatcar-linux.net/amd64-usr/current"
      container_linux_kernel   = "flatcar_production_pxe.vmlinuz"
      container_linux_image    = "flatcar_production_pxe_image.cpio.gz"
    })
  }
}
##
## Desktop (HW) kickstart renderer
##
resource "matchbox_group" "ks-desktop" {
  profile = matchbox_profile.generic-profile.name
  name    = "desktop"
  selector = {
    ks = "desktop"
  }
  metadata = {
    config = templatefile("${path.module}/../../templates/kickstart/desktop.ks.tmpl", {
      user     = var.desktop_user
      password = var.desktop_password
      timezone = var.local_timezone
      networks = var.networks
      hosts    = var.desktop_hosts
      mtu      = var.mtu

      tls_internal_ca      = chomp(var.internal_ca_cert_pem)
      certs_path           = "/usr/share/pki/ca-trust-source/anchors"
      persistent_home_path = "/localhome"
      persistent_home_dev  = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_250GB_S465NB0K598517N-part1"
    })
  }
}
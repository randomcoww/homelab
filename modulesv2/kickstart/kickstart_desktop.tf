##
## Desktop (HW) kickstart renderer
##
resource "matchbox_group" "ks-desktop" {
  for_each = var.desktop_hosts

  profile = matchbox_profile.generic-profile.name
  name    = "desktop-${each.key}"
  selector = {
    ks = "desktop-${each.key}"
  }
  metadata = {
    config = templatefile("${path.module}/../../templates/kickstart/desktop.ks.tmpl", {
      hostname        = each.key
      user            = var.desktop_user
      password        = var.desktop_password
      tls_internal_ca = chomp(var.internal_ca_cert_pem)
      networks        = var.networks
      host_network    = each.value.host_network
      mtu             = var.mtu

      certs_path            = "/usr/share/pki/ca-trust-source/anchors"
      persistent_home_path  = each.value.persistent_home_path
      persistent_home_dev   = each.value.persistent_home_dev
      persistent_home_mount = "${join("-", compact(split("/", each.value.persistent_home_path)))}.mount"
    })
  }
}
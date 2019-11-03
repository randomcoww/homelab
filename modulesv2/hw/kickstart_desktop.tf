##
## Desktop (HW) kickstart renderer
##

resource "matchbox_profile" "ks-desktop" {
  name           = "desktop"
  generic_config = file("${path.module}/../../templates/kickstart/desktop.ks.tmpl")
}

resource "matchbox_group" "ks-desktop" {
  for_each = var.desktop_hosts

  profile = matchbox_profile.ks-desktop.name
  name    = each.key
  selector = {
    ks = each.key
  }
  metadata = {
    hostname              = each.key
    user                  = var.user
    password              = var.password
    persistent_home_path  = each.value.persistent_home_path
    persistent_home_dev   = each.value.persistent_home_dev
    persistent_home_mount = "${join("-", compact(split("/", each.value.persistent_home_path)))}.mount"

    networkd = chomp(templatefile("${path.module}/../../templates/misc/networkd.tmpl", {
      file_path = "/etc/systemd/network"
      priority  = 20
      config    = each.value.network
      vlans = [
        "store"
      ]
      host_tap_vlan = "store"
      host_tap_if   = "host-tap"
      mtu           = var.mtu
      networks      = var.networks
    }))
  }
}
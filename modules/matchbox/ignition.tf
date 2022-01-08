resource "matchbox_profile" "ignition" {
  for_each = var.hosts

  name         = each.key
  kernel       = each.value.kernel
  initrd       = each.value.initrd
  args         = each.value.args
  raw_ignition = each.value.raw_ignition
}

resource "matchbox_group" "ignition" {
  for_each = var.hosts

  profile = matchbox_profile[each.key].ignition.name
  name    = each.key
  selector = {
    mac = each.value.pxeboot_macaddress
  }
}
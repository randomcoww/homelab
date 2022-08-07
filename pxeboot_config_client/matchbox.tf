resource "matchbox_profile" "pxeboot" {
  for_each = local.pxeboot.hosts

  name   = each.key
  kernel = "${local.pxeboot.image_store_endpoint}/${each.value.kernel_image_name}"
  initrd = ["${local.pxeboot.image_store_endpoint}/${each.value.initrd_image_name}"]
  args = concat([
    "elevator=noop",
    "rd.neednet=1",
    "ip=dhcp",
    "ignition.firstboot",
    "ignition.platform.id=metal",
    "coreos.no_persist_ip",
    "initrd=${each.value.initrd_image_name}",
    "ignition.config.url=${local.pxeboot.matchbox_endpoint}/ignition?mac=$${mac:hexhyp}",
    "coreos.live.rootfs_url=${local.pxeboot.image_store_endpoint}/${each.value.rootfs_image_name}",
  ], each.value.boot_args)
  raw_ignition = file("output/ignition/${each.value.ignition}.ign")
}

resource "matchbox_group" "pxeboot" {
  for_each = local.pxeboot.hosts

  profile = matchbox_profile.pxeboot[each.key].name
  name    = each.key
  selector = {
    mac = each.key
  }
}
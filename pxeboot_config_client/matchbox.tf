resource "matchbox_profile" "pxeboot" {
  for_each = local.pxeboot.hosts

  name   = each.key
  kernel = "${local.pxeboot.image_store_endpoint}/${local.pxeboot.image_store_base_path}/${each.value.kernel_image_name}"
  initrd = ["${local.pxeboot.image_store_endpoint}/${local.pxeboot.image_store_base_path}/${each.value.initrd_image_name}"]
  args = concat([
    "rd.neednet=1",
    "ignition.firstboot",
    "ignition.platform.id=metal",
    "initrd=${each.value.initrd_image_name}",
    "ignition.config.url=${local.pxeboot.matchbox_http_endpoint}/ignition?mac=$${mac:hexhyp}",
    "coreos.live.rootfs_url=${local.pxeboot.image_store_endpoint}/${local.pxeboot.image_store_base_path}/${each.value.rootfs_image_name}",
    "ip=dhcp",
  ], each.value.boot_args)
  raw_ignition = file("output/ignition/${each.key}.ign")
}

resource "matchbox_group" "pxeboot" {
  for_each = local.pxeboot.hosts

  profile = matchbox_profile.pxeboot[each.key].name
  name    = each.key
  selector = {
    mac = local.hosts[each.key].hardware_interfaces[each.value.boot_interface].mac
  }
}
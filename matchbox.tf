resource "matchbox_profile" "ignition" {
  for_each = {
    for key, host in local.hosts :
    key => merge(host.network_boot, {
      match_mac = host.physical_interfaces[host.network_boot.interface].match_mac
    }) if contains(keys(host), "network_boot")
  }

  name   = each.value.match_mac
  kernel = "${local.image_store_endpoint}/${each.value.image.kernel}"
  initrd = ["${local.image_store_endpoint}/${each.value.image.initrd}"]
  args = concat([
    "rd.neednet=1",
    "ip=dhcp",
    "ignition.firstboot",
    "ignition.platform.id=metal",
    "coreos.no_persist_ip",
    "initrd=${each.value.image.initrd}",
    "ignition.config.url=${local.matchbox_endpoint}/ignition?mac=$${mac:hexhyp}",
    "coreos.live.rootfs_url=${local.image_store_endpoint}/${each.value.image.rootfs}",
    "rd.driver.blacklist=nouveau",
    "modprobe.blacklist=nouveau",
  ], each.value.boot_args)
  raw_ignition = data.terraform_remote_state.ignition.outputs.ignition[each.key]
}

resource "matchbox_group" "ignition" {
  for_each = matchbox_profile.ignition

  profile = each.value.name
  name    = each.key
  selector = {
    mac = replace(each.value.name, "-", ":")
  }
}

/*
resource "matchbox_profile" "podlist" {
  for_each = data.terraform_remote_state.ignition.outputs.podlist

  name           = each.key
  generic_config = each.value
}

resource "matchbox_group" "podlist" {
  for_each = matchbox_profile.podlist

  profile = each.key
  name    = each.key
  selector = {
    node = local.hosts[each.key].hostname
  }
}
*/
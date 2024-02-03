resource "matchbox_profile" "ignition" {
  for_each = {
    for key, host in local.hosts :
    host.physical_interfaces[host.network_boot.interface].mac => merge(host.network_boot, {
      host_key = key
    }) if lookup(host, "network_boot", null) != null
  }

  name   = each.key
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
  ], each.value.boot_args)
  raw_ignition = data.terraform_remote_state.ign.outputs.ignition[each.value.host_key]
  # Write local files so that this step can work without access to ignition tfstate on S3
  # raw_ignition = file("output/ignition/${each.value.host_key}.ign")
}

resource "matchbox_group" "ignition" {
  for_each = matchbox_profile.ignition

  profile = each.key
  name    = each.key
  selector = {
    mac = replace(each.key, "-", ":")
  }
}

resource "matchbox_profile" "podlist" {
  for_each = data.terraform_remote_state.ign.outputs.podlist

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
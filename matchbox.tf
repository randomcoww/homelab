resource "matchbox_profile" "pxeboot" {
  for_each = {
    for key, host in local.hosts :
    host.hardware_interfaces[host.network_boot.interface].mac => merge(host.network_boot, {
      ignition = key
    }) if lookup(host, "network_boot", null) != null
  }

  name   = each.key
  kernel = "${local.image_store_endpoint}/${each.value.image.kernel}"
  initrd = ["${local.image_store_endpoint}/${each.value.image.initrd}"]
  args = concat([
    "iommu=pt",
    "amd_iommu=pt",
    "rd.driver.pre=vfio-pci",
    "rd.neednet=1",
    "ip=dhcp",
    "ignition.firstboot",
    "ignition.platform.id=metal",
    "coreos.no_persist_ip",
    "initrd=${each.value.image.initrd}",
    "ignition.config.url=${local.matchbox_endpoint}/ignition?mac=$${mac:hexhyp}",
    "coreos.live.rootfs_url=${local.image_store_endpoint}/${each.value.image.rootfs}",
  ], each.value.boot_args)
  # Write local files so that this step can work without access to ignition tfstate on S3
  raw_ignition = file("output/ignition/${each.value.ignition}.ign")
}

resource "matchbox_group" "pxeboot" {
  for_each = matchbox_profile.pxeboot

  profile = each.key
  name    = each.key
  selector = {
    mac = replace(each.key, "-", ":")
  }
}
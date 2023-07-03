locals {
  pxeboot_image_builds = {
    coreos     = "fedora-coreos-38.20230701.0"
    silverblue = "fedora-silverblue-38.20230703.0"
  }

  image_set = {
    for type, tag in local.pxeboot_image_builds :
    type => {
      kernel_image_name = "${tag}-live-kernel-x86_64"
      initrd_image_name = "${tag}-live-initramfs.x86_64.img"
      rootfs_image_name = "${tag}-live-rootfs.x86_64.img"
    }
  }

  pxeboot = {
    hosts = {
      "1c-83-41-30-e2-23" = merge(local.image_set.coreos, {
        ignition = "gw-0"
        boot_args = [
          "systemd.unit=multi-user.target",
          "enforcing=0",
        ]
      })
      "1c-83-41-30-e2-54" = merge(local.image_set.coreos, {
        ignition = "gw-1"
        boot_args = [
          "systemd.unit=multi-user.target",
          "enforcing=0",
        ]
      })
      "1c-83-41-30-bd-6f" = merge(local.image_set.coreos, {
        ignition = "q-0"
        boot_args = [
          "systemd.unit=multi-user.target",
          "enforcing=0",
        ]
      })
      "58-47-ca-71-4d-ce" = merge(local.image_set.silverblue, {
        ignition = "de-0"
        boot_args = [
          "enforcing=0",
          # "vfio-pci.ids=10de:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,10de:ffffffff:ffffffff:ffffffff:00040300:ffffffff",
          # "vfio-pci.ids=1002:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,1002:ffffffff:ffffffff:ffffffff:00040300:ffffffff,10de:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,10de:ffffffff:ffffffff:ffffffff:00040300:ffffffff",
          # "video=efifb:off",
        ]
      })
    }
  }
}

resource "matchbox_profile" "pxeboot" {
  for_each = local.pxeboot.hosts

  name   = each.key
  kernel = "${local.image_store_endpoint}/${each.value.kernel_image_name}"
  initrd = ["${local.image_store_endpoint}/${each.value.initrd_image_name}"]
  args = concat([
    "intel_iommu=on",
    "amd_iommu=on",
    "iommu=pt",
    "rd.driver.pre=vfio-pci",
    "rd.neednet=1",
    "ip=dhcp",
    "ignition.firstboot",
    "ignition.platform.id=metal",
    "coreos.no_persist_ip",
    "initrd=${each.value.initrd_image_name}",
    "ignition.config.url=${local.matchbox_endpoint}/ignition?mac=$${mac:hexhyp}",
    "coreos.live.rootfs_url=${local.image_store_endpoint}/${each.value.rootfs_image_name}",
  ], each.value.boot_args)
  raw_ignition = file("output/ignition/${each.value.ignition}.ign")
}

resource "matchbox_group" "pxeboot" {
  for_each = local.pxeboot.hosts

  profile = matchbox_profile.pxeboot[each.key].name
  name    = each.key
  selector = {
    mac = replace(each.key, "-", ":")
  }
}

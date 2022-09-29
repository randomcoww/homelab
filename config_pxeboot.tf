locals {
  pxeboot_image_builds = {
    coreos            = "fedora-coreos-36.20220818.0"
    silverblue        = "fedora-silverblue-36.20220928.0"
    silverblue-nvidia = "fedora-silverblue-35.20220904.0"
    printer           = "printer-compat"
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
    matchbox_endpoint     = "http://${local.services.matchbox.ip}:${local.ports.matchbox}"
    matchbox_api_endpoint = "${local.services.matchbox.ip}:${local.ports.matchbox_api}"
    image_store_endpoint  = "http://${local.services.minio.ip}:${local.ports.minio}/${local.minio_buckets.image_store}"

    hosts = {
      "1c-83-41-30-e2-23" = merge(local.image_set.coreos, {
        ignition = "gw-0"
        boot_args = [
          "enforcing=0",
          "rfkill.master_switch_mode=2",
          "rfkill.default_state=1",
          "cfg80211.ieee80211_regdom=US",
        ]
      })
      "1c-83-41-30-e2-54" = merge(local.image_set.coreos, {
        ignition = "gw-1"
        boot_args = [
          "enforcing=0",
          "rfkill.master_switch_mode=2",
          "rfkill.default_state=1",
          "cfg80211.ieee80211_regdom=US",
        ]
      })
      "1c-83-41-30-bd-6f" = merge(local.image_set.silverblue, {
        ignition = "q-0"
        boot_args = [
          "enforcing=0",
          "rfkill.master_switch_mode=2",
          "rfkill.default_state=1",
          "cfg80211.ieee80211_regdom=US",
        ]
      })

      "84-a9-38-0f-aa-76" = merge(local.image_set.silverblue-nvidia, {
        ignition = "re-0"
        boot_args = [
          "enforcing=0",
          # "rfkill.master_switch_mode=2",
          "rfkill.default_state=1",
          "rd.driver.blacklist=nouveau",
          "modprobe.blacklist=nouveau",
          "nvidia_drm.modeset=1",
          # "vfio-pci.ids=10de:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,10de:ffffffff:ffffffff:ffffffff:00040300:ffffffff",
          # "vfio-pci.ids=1002:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,1002:ffffffff:ffffffff:ffffffff:00040300:ffffffff,10de:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,10de:ffffffff:ffffffff:ffffffff:00040300:ffffffff",
          # "nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1",
          # "video=efifb:off",
        ]
      })
      "52-54-00-1a-61-1a" = merge(local.image_set.silverblue-nvidia, {
        ignition = "de-1"
        boot_args = [
          "enforcing=0",
          "rd.driver.blacklist=nouveau",
          "modprobe.blacklist=nouveau",
          "nvidia_drm.modeset=1",
        ]
      })
    }
  }
}

locals {
  pxeboot_image_builds = {
    coreos            = "fedora-coreos-36.20220801.0"
    silverblue        = "fedora-silverblue-36.20220730.0"
    silverblue-nvidia = "fedora-silverblue-35.20220720.0"
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
    matchbox_http_endpoint = "http://${local.vips.matchbox}:${local.ports.matchbox_http}"
    matchbox_api_endpoint  = "${local.vips.matchbox}:${local.ports.matchbox_api}"
    image_store_endpoint   = "http://${local.vips.minio}:${local.ports.minio}"
    image_store_base_path  = "boot"

    hosts = {
      "84-a9-38-0f-aa-76" = merge(local.image_set.silverblue-nvidia, {
        ignition = "de-0"
        boot_args = [
          "enforcing=0",
          "rd.driver.blacklist=nouveau",
          "modprobe.blacklist=nouveau",
          "nvidia_drm.modeset=1",
          # "nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1",
          # "intel_iommu=on",
          # "amd_iommu=on",
          # "iommu=pt",
          # "rd.driver.pre=vfio-pci",
          # "vfio-pci.ids=10de:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,10de:ffffffff:ffffffff:ffffffff:00040300:ffffffff",
          # "vfio-pci.ids=1002:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,1002:ffffffff:ffffffff:ffffffff:00040300:ffffffff,10de:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,10de:ffffffff:ffffffff:ffffffff:00040300:ffffffff",
          # "video=efifb:off",
        ]
      })

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
    }
  }
}

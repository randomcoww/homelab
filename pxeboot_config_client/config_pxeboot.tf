locals {
  pxeboot_image_builds = {
    client = "fedora-silverblue-35.20220212.0"
  }

  pxeboot = {
    matchbox_http_endpoint = "http://${local.networks.metallb.vips.internal_pxeboot}:${local.ports.internal_pxeboot_http}"
    matchbox_api_endpoint  = "${local.networks.metallb.vips.internal_pxeboot}:${local.ports.internal_pxeboot_api}"
    image_store_endpoint   = "http://${local.networks.metallb.vips.minio}:${local.ports.minio}"
    image_store_base_path  = "boot"

    hosts = {
      client-0 = {
        selector_mac = "84-a9-38-0f-aa-76"
        boot_args = [
          "systemd.unified_cgroup_hierarchy=0",
          "intel_iommu=on",
          "amd_iommu=on",
          "iommu=pt",
          "enforcing=0",
          "elevator=noop",
          "rd.driver.pre=vfio-pci",
          "rd.driver.blacklist=nouveau",
          "modprobe.blacklist=nouveau",
          "nvidia-drm.modeset=1",
          # VFIO passthrough
          # "vfio-pci.ids=10de:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,10de:ffffffff:ffffffff:ffffffff:00040300:ffffffff",
          # "vfio-pci.ids=1002:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,1002:ffffffff:ffffffff:ffffffff:00040300:ffffffff,10de:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,10de:ffffffff:ffffffff:ffffffff:00040300:ffffffff",
          # "video=efifb:off",
          # Brightness control in wayland
          # "nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1",
        ]
        kernel_image_name = "${local.pxeboot_image_builds.client}-live-kernel-x86_64"
        initrd_image_name = "${local.pxeboot_image_builds.client}-live-initramfs.x86_64.img"
        rootfs_image_name = "${local.pxeboot_image_builds.client}-live-rootfs.x86_64.img"
      }
    }
  }
}
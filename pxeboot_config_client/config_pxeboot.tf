locals {
  pxeboot_image_builds = {
    client = "fedora-silverblue-35.20220203.0"
  }

  pxeboot = {
    matchbox_ip = cidrhost(
      cidrsubnet(local.networks.lan.prefix, local.kubernetes.metallb_subnet.newbit, local.kubernetes.metallb_subnet.netnum),
      local.kubernetes.metallb_pxeboot_netnum
    )
    matchbox_http_endpoint = "http://${local.matchbox_ip}:${local.ports.internal_pxeboot_http}"
    matchbox_api_endpoint  = "${local.matchbox_ip}:${local.ports.internal_pxeboot_api}"

    image_store_ip = cidrhost(
      cidrsubnet(local.networks.lan.prefix, local.kubernetes.metallb_subnet.newbit, local.kubernetes.metallb_subnet.netnum),
      local.kubernetes.metallb_minio_netnum
    )
    image_store_endpoint  = "http://${local.image_store_ip}:${local.ports.minio}"
    image_store_base_path = "boot"

    hosts = {
      client-0 = {
        host_spec      = "client-laptop",
        boot_interface = "phy0"
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
          "nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1",
        ]
        kernel_image_name = "${local.pxeboot_image_builds.client}-live-kernel-x86_64"
        initrd_image_name = "${local.pxeboot_image_builds.client}-live-initramfs.x86_64.img"
        rootfs_image_name = "${local.pxeboot_image_builds.client}-live-rootfs.x86_64.img"
      }
    }
  }
}
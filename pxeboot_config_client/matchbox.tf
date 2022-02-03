
locals {
  pxeboot_hosts = {
    aio-0 = {
      host_spec      = "server-laptop",
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
      ]
      kernel_image_name = "fedora-coreos-35.20220203.0-live-kernel-x86_64"
      initrd_image_name = "fedora-coreos-35.20220203.0-live-initramfs.x86_64.img"
      rootfs_image_name = "fedora-coreos-35.20220203.0-live-rootfs.x86_64.img"
    }

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
      kernel_image_name = "fedora-silverblue-35.20220203.0-live-kernel-x86_64"
      initrd_image_name = "fedora-silverblue-35.20220203.0-live-initramfs.x86_64.img"
      rootfs_image_name = "fedora-silverblue-35.20220203.0-live-rootfs.x86_64.img"
    }
  }
}

resource "matchbox_profile" "pxeboot" {
  for_each = local.pxeboot_hosts

  name   = each.key
  kernel = "${local.image_store_endpoint}/${local.image_store_base_path}/${each.value.kernel_image_name}"
  initrd = ["${local.image_store_endpoint}/${local.image_store_base_path}/${each.value.initrd_image_name}"]
  args = concat([
    "rd.neednet=1",
    "ignition.firstboot",
    "ignition.platform.id=metal",
    "initrd=${each.value.initrd_image_name}",
    "ignition.config.url=${local.matchbox_http_endpoint}/ignition?mac=$${mac:hexhyp}",
    "coreos.live.rootfs_url=${local.image_store_endpoint}/${local.image_store_base_path}/${each.value.rootfs_image_name}",
    "ip=dhcp",
  ], each.value.boot_args)
  raw_ignition = file("output/ignition/${each.key}.ign")
}

resource "matchbox_group" "pxeboot" {
  for_each = local.pxeboot_hosts

  profile = matchbox_profile.pxeboot[each.key].name
  name    = each.key
  selector = {
    mac = local.host_spec[each.value.host_spec].hardware_interfaces[each.value.boot_interface].mac
  }
}
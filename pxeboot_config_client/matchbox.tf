locals {
  matchbox_ip = cidrhost(
    cidrsubnet(local.networks.lan.prefix, local.kubernetes.metallb_subnet.newbit, local.kubernetes.metallb_subnet.netnum),
    local.kubernetes.metallb_pxeboot_netnum
  )
  image_store_ip = cidrhost(local.networks.lan.prefix, local.aio_hostclass_config.vrrp_netnum)

  host_key               = "client-0"
  client_image_name_base = "fedora-silverblue-35.20220130.0"
  boot_args = [
    "systemd.unified_cgroup_hierarchy=0",
    "intel_iommu=on",
    "amd_iommu=on",
    "iommu=pt",
    "enforcing=0",
    "elevator=noop",
    "rd.driver.blacklist=nouveau",
    "modprobe.blacklist=nouveau",
    "nvidia-drm.modeset=1",
    "nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1",
  ]

  matchbox_api_endpoint = "http://${local.matchbox_ip}:${local.ports.internal_pxeboot_http}"
  image_store_endpoint  = "http://${local.image_store_ip}:${local.ports.minio}"
  image_store_base_path = "boot"
  kernel_image_name     = "${local.client_image_name_base}-live-kernel-x86_64"
  initrd_image_name     = "${local.client_image_name_base}-live-initramfs.x86_64.img"
  rootfs_image_name     = "${local.client_image_name_base}-live-rootfs.x86_64.img"
  ignition_content      = file("output/ignition/${local.host_key}.ign")
  selector_mac          = local.host_spec[local.host_key].hardware_interfaces.lan.mac

  provider = {
    endpoint = "${local.matchbox_ip}:${local.ports.internal_pxeboot_api}"
    ca_pem   = file("output/certs/matchbox-ca.pem")
    cert_pem = file("output/certs/matchbox-cert.pem")
    key_pem  = file("output/certs/matchbox-key.pem")
  }
}

resource "matchbox_profile" "pxeboot" {
  name   = local.host_key
  kernel = "${local.image_store_endpoint}/${local.image_store_base_path}/${local.kernel_image_name}"
  initrd = ["${local.image_store_endpoint}/${local.image_store_base_path}/${local.initrd_image_name}"]
  args = concat([
    "rd.neednet=1",
    "ignition.firstboot",
    "ignition.platform.id=metal",
    "initrd=${local.initrd_image_name}",
    "ignition.config.url=${local.matchbox_api_endpoint}/ignition?mac=$${mac:hexhyp}",
    "coreos.live.rootfs_url=${local.image_store_endpoint}/${local.image_store_base_path}/${local.rootfs_image_name}",
    "ip=dhcp",
  ], local.boot_args)
  raw_ignition = local.ignition_content
}

resource "matchbox_group" "pxeboot" {
  profile = matchbox_profile.pxeboot.name
  name    = local.host_key
  selector = {
    mac = local.selector_mac
  }
}
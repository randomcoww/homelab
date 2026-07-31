locals {
  host_images = {
    for name, tag in {
      default = "44.20260730.20.1" # renovate: datasource=github-tags depName=randomcoww/fedora-coreos-config-custom
    } :
    name => {
      kernel = "fedora-coreos-${tag}-live-kernel.$${buildarch:uristring}"
      initrd = "fedora-coreos-${tag}-live-initramfs.$${buildarch:uristring}.img"
      rootfs = "fedora-coreos-${tag}-live-rootfs.$${buildarch:uristring}.img"
    }
  }
  current_host_image = local.host_images.default

  netboot_args = {
    for host_key, host in local.hosts :
    host_key => sort(concat([
      "rd.neednet=1",
      "ip=dhcp",
      "ignition.firstboot",
      "ignition.platform.id=metal",
      "coreos.no_persist_ip",
      "initrd=${local.current_host_image.initrd}",
      "ignition.config.url=https://${local.endpoints.minio.service_ip}:${local.service_ports.minio}/boot/ignition-$${mac:hexhyp}",
      "coreos.live.rootfs_url=https://${local.endpoints.minio.service_ip}:${local.service_ports.minio}/boot/${local.current_host_image.rootfs}",
      "rd.driver.blacklist=nouveau,nova_core",
      "modprobe.blacklist=nouveau,nova_core",
      "selinux=0",
      "amd_iommu=off",                                                                                              # memory performance for LLM
      "ipxe.url=https://${local.endpoints.minio.service_ip}:${local.service_ports.minio}/boot/ipxe-$${mac:hexhyp}", # for custom update check
    ], host.boot_args))
  }
  netboot_config = {
    for mac, host_key in transpose({
      for k, host in local.hosts :
      k => host.match_macs
    }) :
    mac => merge(local.current_host_image, {
      host_key = host_key[0]
      netboot_args = concat(local.netboot_args[host_key[0]], [
        "digest=${sha256("${join(" ", concat([local.current_host_image.kernel], local.netboot_args[host_key[0]]))} ${data.ct_config.ignition[host_key[0]].rendered}")}",
      ])
    })
  }
}

data "ct_config" "ignition" {
  for_each = data.terraform_remote_state.host.outputs.ignition_snippets

  content = yamlencode({
    variant = "fcos"
    version = local.butane_version
  })
  pretty_print = false
  strict       = true
  snippets     = sort(each.value)
}

# ignition-<mac> files read by ipxe
resource "minio_s3_object" "ignition" {
  for_each = {
    for mac, boot in local.netboot_config :
    mac => data.ct_config.ignition[boot.host_key].rendered
  }

  bucket_name  = "boot"
  object_name  = "ignition-${each.key}"
  content_type = "application/json"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["boot"],
  ]
}

# ipxe-<mac> files read by kea DHCP
resource "minio_s3_object" "ipxe" {
  for_each = local.netboot_config

  bucket_name  = "boot"
  object_name  = "ipxe-${each.key}"
  content_type = "text/plain"
  content      = <<-EOF
  #!ipxe
  kernel https://${local.endpoints.minio.service_ip}:${local.service_ports.minio}/boot/${each.value.kernel} ${join(" ", each.value.netboot_args)}
  initrd https://${local.endpoints.minio.service_ip}:${local.service_ports.minio}/boot/${each.value.initrd}
  boot
  EOF

  depends_on = [
    minio_s3_bucket.static-bucket["boot"],
  ]
}

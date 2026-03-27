locals {
  boot_config = {
    for mac, host_key in transpose({
      for k, host in local.hosts :
      k => host.match_macs
    }) :
    mac => merge(local.hosts[host_key[0]].host_image, {
      host_key  = host_key[0]
      boot_args = lookup(local.hosts[host_key[0]], "boot_args", [])
    })
  }

  ipxe_configs = {
    for host_key, host in local.hosts :
    host_key => <<-EOF
    #!ipxe
    kernel https://${local.services.minio.ip}:${local.service_ports.minio}/boot/${host.host_image.kernel} ${join(" ", sort(concat([
    "rd.neednet=1",
    "ip=dhcp",
    "ignition.firstboot",
    "ignition.platform.id=metal",
    "coreos.no_persist_ip",
    "initrd=${host.host_image.initrd}",
    "ignition.config.url=https://${local.services.minio.ip}:${local.service_ports.minio}/boot/ignition-$${mac:hexhyp}",
    "coreos.live.rootfs_url=https://${local.services.minio.ip}:${local.service_ports.minio}/boot/${host.host_image.rootfs}",
    "rd.driver.blacklist=nouveau,nova_core",
    "modprobe.blacklist=nouveau,nova_core",
    "selinux=0",
    "amd_iommu=off", # memory performance for LLM
], host.boot_args)))}
    initrd https://${local.services.minio.ip}:${local.service_ports.minio}/boot/${host.host_image.initrd}
    boot
    EOF
}
}

resource "minio_s3_object" "ipxe" {
  for_each = {
    for mac, boot in local.boot_config :
    mac => local.ipxe_configs[boot.host_key]
  }

  bucket_name  = "boot"
  object_name  = "ipxe-${each.key}"
  content_type = "text/plain"
  content      = each.value

  depends_on = [
    minio_s3_bucket.bucket["boot"],
  ]
}

resource "minio_s3_object" "ignition" {
  for_each = {
    for mac, boot in local.boot_config :
    mac => data.terraform_remote_state.host.outputs.ignition[boot.host_key]
  }

  bucket_name  = "boot"
  object_name  = "ignition-${each.key}"
  content_type = "application/json"
  content      = each.value

  depends_on = [
    minio_s3_bucket.bucket["boot"],
  ]
}
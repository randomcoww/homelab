locals {
  minio_endpoint = "${local.services.minio.ip}:${local.service_ports.minio}"
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

  # use for change detection
  ipxe_configs = {
    for mac, boot in local.boot_config :
    mac => <<-EOF
    #!ipxe
    kernel https://${local.minio_endpoint}/boot/${boot.kernel} ${join(" ", sort(concat([
    "rd.neednet=1",
    "ip=dhcp",
    "ignition.firstboot",
    "ignition.platform.id=metal",
    "coreos.no_persist_ip",
    "initrd=${boot.initrd}",
    "ignition.config.url=https://${local.minio_endpoint}/boot/ignition-$${mac:hexhyp}",
    "coreos.live.rootfs_url=https://${local.minio_endpoint}/boot/${boot.rootfs}",
    "rd.driver.blacklist=nouveau,nova_core",
    "modprobe.blacklist=nouveau,nova_core",
    "selinux=0",
    "amd_iommu=off", # memory performance for LLM
], boot.boot_args)))}
    initrd https://${local.minio_endpoint}/boot/${boot.initrd}
    boot
    EOF
}

# use for change detection
ignition_configs = {
  for mac, boot in local.boot_config :
  mac => data.terraform_remote_state.ignition.outputs.ignition[boot.host_key]
}
}

resource "minio_s3_object" "ipxe" {
  for_each = local.boot_config

  bucket_name  = "boot"
  object_name  = "ipxe-${each.key}"
  content_type = "text/plain"
  content      = local.ipxe_configs[each.key]

  depends_on = [
    minio_s3_bucket.bucket["boot"],
  ]
}

resource "minio_s3_object" "ignition" {
  for_each = local.boot_config

  bucket_name  = "boot"
  object_name  = "ignition-${each.key}"
  content_type = "application/json"
  content      = local.ignition_configs[each.key]

  depends_on = [
    minio_s3_bucket.bucket["boot"],
  ]
}
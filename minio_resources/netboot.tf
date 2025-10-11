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
}

resource "minio_s3_object" "ipxe" {
  for_each = local.boot_config

  bucket_name  = "boot"
  object_name  = "ipxe-${each.key}"
  content_type = "text/plain"
  content = <<-EOF
  #!ipxe
  kernel https://${local.minio_endpoint}/boot/${each.value.kernel} ${join(" ", concat([
  "rd.neednet=1",
  "ip=dhcp",
  "ignition.firstboot",
  "ignition.platform.id=metal",
  "coreos.no_persist_ip",
  "initrd=${each.value.initrd}",
  "ignition.config.url=https://${local.minio_endpoint}/boot/ignition-$${mac:hexhyp}",
  "coreos.live.rootfs_url=https://${local.minio_endpoint}/boot/${each.value.rootfs}",
  "rd.driver.blacklist=nouveau",
  "modprobe.blacklist=nouveau",
  "selinux=0",
], each.value.boot_args))}
  initrd https://${local.minio_endpoint}/boot/${each.value.initrd}
  boot
  EOF

depends_on = [
  minio_s3_bucket.bucket["boot"],
]
}

resource "minio_s3_object" "ignition" {
  for_each = local.boot_config

  bucket_name  = "boot"
  object_name  = "ignition-${each.key}"
  content_type = "application/json"
  content      = data.terraform_remote_state.ignition.outputs.ignition[each.value.host_key]

  depends_on = [
    minio_s3_bucket.bucket["boot"],
  ]
}
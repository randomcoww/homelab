locals {
  netboot_base_url = "https://${local.networks.service.vips.minio}:${local.service_ports.minio}/boot"
  netboot_custom_kargs = {
    ipxe_url    = "custom.ipxe_url"
    liveiso_url = "custom.liveiso_url"
    digest      = "custom.digest"
    build_tag   = "custom.build_tag"
  }

  netboot_images = {
    for name, tag in {
      default = "44.20260822.20.1.1787471591" # renovate: datasource=github-tags depName=randomcoww/fedora-coreos-config-custom
    } :
    name => {
      kernel    = "fedora-coreos-${tag}-live-kernel.$${buildarch:uristring}"
      initrd    = "fedora-coreos-${tag}-live-initramfs.$${buildarch:uristring}.img"
      rootfs    = "fedora-coreos-${tag}-live-rootfs.$${buildarch:uristring}.img"
      liveiso   = "fedora-coreos-${tag}-live-iso.$${buildarch:uristring}.iso"
      build_tag = tag
    }
  }
  current_netboot_image = local.netboot_images.default

  netboot_args = {
    for key, host in local.hosts :
    key => concat([
      "rd.neednet=1",
      "ip=dhcp",
      "ignition.firstboot",
      "ignition.platform.id=metal",
      "coreos.no_persist_ip",
      "initrd=${local.current_netboot_image.initrd}",
      "ignition.config.url=${local.netboot_base_url}/ignition-$${mac:hexhyp}",
      "coreos.live.rootfs_url=${local.netboot_base_url}/${local.current_netboot_image.rootfs}",
      "rd.driver.blacklist=nouveau,nova_core",
      "modprobe.blacklist=nouveau,nova_core",
      "selinux=0",
      "amd_iommu=off",                                                                        # memory performance for LLM
      "${local.netboot_custom_kargs.ipxe_url}=${local.netboot_base_url}/ipxe-$${mac:hexhyp}", # for custom update check
      "${local.netboot_custom_kargs.liveiso_url}=${local.netboot_base_url}/${local.current_netboot_image.liveiso}",
      "${local.netboot_custom_kargs.build_tag}=${local.current_netboot_image.build_tag}",
    ], host.boot_args)
  }
  netboot_config = {
    for mac, host in merge([
      for key, host in local.hosts : {
        for _, iface in lookup(host, "wired_interfaces", []) :
        iface.match_mac => host if contains(keys(iface), "match_mac")
      }
    ]...) :
    mac => merge(local.current_netboot_image, {
      key = host.key
      netboot_args = sort(concat(local.netboot_args[host.key], [
        "${local.netboot_custom_kargs.digest}=${sha256("${join(" ", concat([local.current_netboot_image.kernel], local.netboot_args[host.key]))} ${data.ct_config.ignition[host.key].rendered}")}",
      ]))
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
    mac => data.ct_config.ignition[boot.key].rendered
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
  kernel ${local.netboot_base_url}/${each.value.kernel} ${join(" ", each.value.netboot_args)}
  initrd ${local.netboot_base_url}/${each.value.initrd}
  boot
  EOF

  depends_on = [
    minio_s3_bucket.static-bucket["boot"],
  ]
}

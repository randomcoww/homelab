locals {
  ipxe-presign_port = 8080

  netboot_base_url = "https://${local.networks.service.vips.minio}:${local.service_ports.minio}/boot"
  netboot_custom_kargs = {
    liveiso_url = "custom.liveiso_url"
    digest      = "custom.digest"
    build_tag   = "custom.build_tag"
  }

  netboot_images = {
    for name, tag in {
      default = "44.20260916.20.1.1789598080" # renovate: datasource=github-tags depName=randomcoww/fedora-coreos-config-custom
    } :
    name => {
      kernel    = "fedora-coreos-${tag}-live-kernel.$${buildarch:uristring}"
      initrd    = "fedora-coreos-${tag}-live-initramfs.$${buildarch:uristring}.img"
      rootfs    = "fedora-coreos-${tag}-live-rootfs.$${buildarch:uristring}.img"
      liveiso   = "fedora-coreos-${tag}-live-iso.$${buildarch:uristring}.iso"
      build_tag = tag
    }
  }
  netboot_current_image = local.netboot_images.default

  netboot_common_profile = {
    kernelURL = "${local.netboot_base_url}/${local.netboot_current_image.kernel}"
    initrdURLs = [
      "${local.netboot_base_url}/${local.netboot_current_image.initrd}",
    ]
    kargs = sort([
      "rd.neednet=1",
      "ip=dhcp",
      "ignition.firstboot",
      "ignition.platform.id=metal",
      "coreos.no_persist_ip",
      "initrd=${basename(local.netboot_current_image.initrd)}",
      "ignition.config.url={{ presign `ignition-$${mac:hexhyp}` }}",
      "coreos.live.rootfs_url=${local.netboot_base_url}/${local.netboot_current_image.rootfs}",
      "rd.driver.blacklist=nouveau,nova_core",
      "modprobe.blacklist=nouveau,nova_core",
      "selinux=0",
      "amd_iommu=off", # memory performance for LLM
      "${local.netboot_custom_kargs.liveiso_url}=${local.netboot_base_url}/${local.netboot_current_image.liveiso}",
      "${local.netboot_custom_kargs.build_tag}=${local.netboot_current_image.build_tag}",
    ])
  }

  netboot_host_profiles = {
    for host_key, ign in data.ct_config.ignition :
    host_key => {
      kargs = sort(lookup(local.hosts[host_key], "boot_args", []))
    }
  }

  netboot_host_digest = {
    for host_key, profile in local.netboot_host_profiles :
    host_key => sha256("${join(" ", concat(
      [
        data.ct_config.ignition[host_key].rendered,
        local.netboot_common_profile.kernelURL,
      ],
      local.netboot_common_profile.initrdURLs,
      local.netboot_common_profile.kargs,
      profile.kargs,
    ))}")
  }

  netboot_host_mac = {
    for mac, host_key in merge([
      for host_key, host in local.hosts : {
        for _, iface in lookup(host, "wired_interfaces", []) :
        iface.match_mac => host_key if contains(keys(iface), "match_mac")
      }
    ]...) :
    mac => host_key
  }
}

# Add resources to bucket

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

resource "minio_s3_bucket" "ipxe-presign" {
  bucket         = "ipxe-presign"
  acl            = "private"
  force_destroy  = true
  object_locking = false
}

resource "minio_iam_user" "ipxe-presign" {
  name          = "ipxe-presign"
  force_destroy = true
}

resource "minio_iam_policy" "ipxe-presign" {
  name = "ipxe-presign"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          minio_s3_bucket.ipxe-presign.arn,
          "${minio_s3_bucket.ipxe-presign.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "ipxe-presign" {
  user_name   = minio_iam_user.ipxe-presign.id
  policy_name = minio_iam_policy.ipxe-presign.id
}

## Host boot config by mac ##

# ignition-<mac> files read by ipxe
resource "minio_s3_object" "ignition" {
  for_each = local.netboot_host_mac

  bucket_name  = "ipxe-presign"
  object_name  = "ignition-${each.key}"
  content_type = "application/json"
  content      = data.ct_config.ignition[each.value].rendered

  depends_on = [
    minio_s3_bucket.ipxe-presign,
  ]
}

module "ipxe-presign" {
  source    = "./modules/ipxe-presign"
  name      = "ipxe-presign"
  namespace = "hostnet"
  images = {
    ipxe-presign = {
      repository = "zot.cluster.internal/randomcoww/ipxe-presign"
      tag        = "v0.2.1@sha256:71bf73acf3dd8ea1f613401053c06bb320b5bbba0147aebaf01ec400be35c603" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/ipxe-presign
    }
  }
  ca_issuer_name = local.cert_issuers.ca_internal
  service_port   = local.ipxe-presign_port
  service_ip     = local.networks.service.vips.ipxe-presign

  extra_configs = {
    s3Endpoint       = "https://${local.networks.service.vips.minio}:${local.service_ports.minio}"
    s3Bucket         = "ipxe-presign"
    allowedClientCNs = ["gha", "kea"]
    presignTTL       = "240s" # one node hangs for around 2 minutes during network boot
    profiles = concat([
      local.netboot_common_profile,
      ], [
      for mac, host in local.netboot_host_mac :
      merge(local.netboot_host_profiles[host], {
        selector = {
          "mac:hexhyp" = [mac],
        }
        kargs = concat(local.netboot_host_profiles[host].kargs, [
          "${local.netboot_custom_kargs.digest}=${local.netboot_host_digest[host]}"
        ])
      })
    ])
  }
  minio_user = minio_iam_user.ipxe-presign
}

resource "minio_s3_object" "fluxcd-ipxe-presign" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.ipxe-presign.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "ipxe-presign/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}

# outputs

output "netboot-host-digest" {
  value = local.netboot_host_digest
}
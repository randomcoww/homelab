module "kured" {
  source    = "./modules/kured"
  name      = "kured"
  namespace = "monitoring"
  images = {
    kured = {
      repository = "ghcr.io/kubereboot/kured"
      tag        = "1.23.0@sha256:8dfd3c2e889337595731d801afc5c031b545876a29427897b3f711d2983f30c4" # renovate: datasource=docker depName=ghcr.io/kubereboot/kured
    }
  }
  kured_config = {
    prometheusUrl = "https://${local.endpoints.victoria-metrics.hostname}/select/prometheus"
    alertFilterRegexp = "^(${join("|", sort([
      "Watchdog",             # always on, severity: none
      "InfoInhibitor",        # severity: none
      "RecordingRulesNoData", # can fail if no pods have cycled for some time (i.e. healthy)
    ]))})$"
    blockingPodSelector = [
      "app.kubernetes.io/part-of=gha-runner-scale-set,app.kubernetes.io/component=runner",
    ]
    timeZone = local.timezone
  }
  reboot_required_script = <<-EOF
  #!/bin/bash
  set -xe -o pipefail

  if [ -f /var/run/reboot-required ]; then
    exit 0
  fi
  if [ -z $(xargs -n1 -a /proc/cmdline | grep ^${local.custom_kargs.ipxe_url}=) ]; then
    exit 0
  fi
  ipxe_url=$(xargs -n1 -a /proc/cmdline | grep ^${local.custom_kargs.ipxe_url}= | sed -r 's/^${local.custom_kargs.ipxe_url}=//')
  remote_digest=$(curl -fsSL --remove-on-error $ipxe_url | grep ^kernel | xargs -n1 | grep ^${local.custom_kargs.digest}= | sed -e 's/^${local.custom_kargs.digest}=//')
  digest=$(xargs -n1 -a /proc/cmdline | grep ^${local.custom_kargs.digest}= | sed -e 's/^${local.custom_kargs.digest}=//')
  if [ "$remote_digest" != "$digest" ]; then
    exit 0
  fi
  exit 1
  EOF
}

resource "minio_s3_object" "fluxcd-kured" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.kured.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "kured/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}

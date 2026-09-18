module "kured" {
  source    = "./modules/kured"
  name      = "kured"
  namespace = "host-system"
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
    timeZone     = local.timezone
    slackChannel = "bot"
    notifyUrl    = "slack://hook:${join("-", slice(split("/", var.slack_alert_webhook), 4, 7))}@webhook"
  }
  reboot_required_script = <<-EOF
  #!/bin/bash
  set -xe -o pipefail

  # Check if booted over network
  if ! grep -q 'ignition.config.url=' /proc/cmdline; then
    exit 0
  fi

  # Compare target digest written by remote_exec
  if [ -f /var/run/reboot-required ] && grep -q '${local.netboot_custom_kargs.digest}=' /proc/cmdline; then
    target_digest=$(cat /var/run/reboot-required)
    current_digest=$(xargs -n1 -a /proc/cmdline | grep '^${local.netboot_custom_kargs.digest}=' | sed -r 's/^${local.netboot_custom_kargs.digest}=//')

    if [ "$target_digest" != "$current_digest" ]; then
      exit 0
    fi
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

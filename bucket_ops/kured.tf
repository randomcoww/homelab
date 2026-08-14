resource "minio_s3_object" "fluxcd-kured" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "kured"
            namespace = "monitoring"
          }
          spec = {
            interval = "15m"
            url      = "https://kubereboot.github.io/charts"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "kured"
            namespace = "monitoring"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "kured"
                version = "6.1.0" # renovate: datasource=helm depName=kured registryUrl=https://kubereboot.github.io/charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = "kured"
                }
                interval = "5m"
              }
            }
            releaseName = "kured"
            install = {
              createNamespace = true
              remediation = {
                retries = -1
              }
            }
            upgrade = {
              remediation = {
                retries = -1
              }
            }
            test = {
              enable = false
            }
            values = {
              # manifest #

              configuration = {
                prometheusUrl = "https://${local.httproutes.victoria-metrics.hostname}/select/prometheus"
                period        = "2m"
                forceReboot   = true
                drainTimeout  = "6m"
                alertFilterRegexp = "^(${join("|", sort([
                  "Watchdog",             # always on, severity: none
                  "InfoInhibitor",        # severity: none
                  "RecordingRulesNoData", # can fail if no pods have cycled for some time (i.e. healthy)
                ]))})$"
                blockingPodSelector = [
                  "app.kubernetes.io/part-of=gha-runner-scale-set,app.kubernetes.io/component=runner",
                ]
                timeZone = local.timezone
                # trigger reboot if either /var/run/reboot-required is set, or node failed network boot
                useRebootSentinelHostPath = false
                rebootSentinelCommand     = "reboot-required.sh"
              }
              resources = {
                requests = {
                  memory = "32Mi"
                }
                limits = {
                  memory = "64Mi"
                }
              }
              priorityClassName = "system-node-critical"
              metrics = {
                create    = true
                namespace = "monitoring"
              }
              service = {
                create = true
              }
              volumeMounts = [
                {
                  name      = "ca-trust-bundle"
                  mountPath = "/etc/ssl/certs/ca-certificates.crt"
                  readOnly  = true
                },
              ]
              volumes = [
                {
                  name = "ca-trust-bundle"
                  hostPath = {
                    path = "/etc/ssl/certs/ca-certificates.crt"
                    type = "File"
                  }
                },
              ]
            }
          }
        },
      ] :
      yamlencode(m)
    ])
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
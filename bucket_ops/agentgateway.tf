locals {
  agentgateway_name      = "agentgateway"
  agentgateway_namespace = "agentgateway-system"
}

resource "minio_s3_object" "fluxcd-agentgateway" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "OCIRepository"
          metadata = {
            name      = local.agentgateway_name
            namespace = local.agentgateway_namespace
          }
          spec = {
            interval = "15m"
            url      = "oci://cr.agentgateway.dev/charts/agentgateway"
            ref = {
              tag = "v1.5.0" # renovate: datasource=docker depName=cr.agentgateway.dev/charts/agentgateway depType=helm_regex
            }
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = local.agentgateway_name
            namespace = local.agentgateway_namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chartRef = {
              kind      = "OCIRepository"
              name      = local.agentgateway_name
              namespace = local.agentgateway_namespace
            }
            releaseName = local.agentgateway_name
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
              controller = {
                extraEnv = {
                  CLUSTER_DOMAIN = local.domains.kubernetes
                  TRUST_DOMAIN   = local.domains.kubernetes
                }
              }
              agentgatewayModels = {
                enabled = false
              }
              inferenceExtension = {
                enabled = true
              }
              istio = {
                enabled = false
              }
              monitoring = {
                enabled = true
                grafanaDashboard = {
                  enabled = false
                }
              }
            }
          }
        },

        # NS
        {
          apiVersion = "v1"
          kind       = "Namespace"
          metadata = {
            name = local.agentgateway_namespace
            annotations = {
              "kustomize.toolkit.fluxcd.io/prune" = "disabled"
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
  object_name  = "agentgateway/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}
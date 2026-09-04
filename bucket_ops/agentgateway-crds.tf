resource "minio_s3_object" "fluxcd-agentgateway-crds" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "OCIRepository"
          metadata = {
            name      = "${local.agentgateway_name}-crds"
            namespace = local.agentgateway_namespace
          }
          spec = {
            interval = "15m"
            url      = "oci://ghcr.io/agentgateway/charts/agentgateway-crds"
            ref = {
              tag = "v2.2.1" # renovate: datasource=docker depName=ghcr.io/agentgateway/charts/agentgateway-crds depType=helm_regex
            }
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "${local.agentgateway_name}-crds"
            namespace = local.agentgateway_namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chartRef = {
              kind      = "OCIRepository"
              name      = "${local.agentgateway_name}-crds"
              namespace = local.agentgateway_namespace
            }
            releaseName = "${local.agentgateway_name}-crds"
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
  object_name  = "agentgateway-crds/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}
resource "minio_s3_object" "fluxcd-agentgateway-crds" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "OCIRepository"
          metadata = {
            name      = "${local.services.agentgateway.name}-crds"
            namespace = local.services.agentgateway.namespace
          }
          spec = {
            interval = "15m"
            url      = "oci://cr.agentgateway.dev/charts/agentgateway-crds"
            ref = {
              tag = "v1.5.0" # renovate: datasource=docker depName=cr.agentgateway-crds.dev/charts/agentgateway-crds depType=helm_regex
            }
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "${local.services.agentgateway.name}-crds"
            namespace = local.services.agentgateway.namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chartRef = {
              kind      = "OCIRepository"
              name      = "${local.services.agentgateway.name}-crds"
              namespace = local.services.agentgateway.namespace
            }
            releaseName = "${local.services.agentgateway.name}-crds"
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
            name = local.services.agentgateway.namespace
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
resource "minio_s3_object" "fluxcd-kagent-crds" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "OCIRepository"
          metadata = {
            name      = "${local.kagent_name}-crds"
            namespace = local.kagent_namespace
          }
          spec = {
            interval = "6h"
            url      = "oci://ghcr.io/kagent-dev/kagent/helm/kagent-crds"
            ref = {
              tag = "0.10.4" # renovate: datasource=docker depName=ghcr.io/kagent-dev/kagent/helm/kagent-crds depType=helm_regex
            }
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "${local.kagent_name}-crds"
            namespace = local.kagent_namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chartRef = {
              kind      = "OCIRepository"
              name      = "${local.kagent_name}-crds"
              namespace = local.kagent_namespace
            }
            releaseName = "${local.kagent_name}-crds"
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
  object_name  = "kagent-crds/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}

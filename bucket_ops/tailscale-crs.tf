resource "minio_s3_object" "fluxcd-tailscale-crs" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "tailscale.com/v1alpha1"
          kind       = "Connector"
          metadata = {
            name = "ts-${local.kubernetes.cluster_name}"
          }
          spec = {
            replicas       = 2
            hostnamePrefix = "ts-${local.kubernetes.cluster_name}"
            subnetRouter = {
              advertiseRoutes = distinct([
                cidrsubnet(local.networks.service.prefix, -1, 0), # hack to use a bigger range so that service network route can be overriden for local access
              ])
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
  object_name  = "tailscale-crs/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}
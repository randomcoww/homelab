module "kubernetes-mcp" {
  source    = "./modules/kubernetes-mcp"
  name      = local.endpoints.kubernetes-mcp.name
  namespace = local.endpoints.kubernetes-mcp.namespace
  images = {
    kubernetes-mcp = {
      repository = "ghcr.io/containers/kubernetes-mcp-server"
      tag        = "v0.0.66@sha256:6d650f4bd6ac303ad82713c997e73a2d001602f9bf17392c9b9a0e30e29c6423" # renovate: datasource=docker depName=ghcr.io/containers/kubernetes-mcp-server
    }
  }
  service_hostname = local.endpoints.kubernetes-mcp.service
  service_port     = local.service_ports.kubernetes_mcp
  ca_issuer_name   = local.cert_issuers.ca_internal
}

resource "minio_s3_object" "fluxcd-kubernetes-mcp" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.kubernetes-mcp.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "kubernetes-mcp/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}

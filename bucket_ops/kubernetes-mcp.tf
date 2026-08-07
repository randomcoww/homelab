locals {
  kubernetes-mcp_name      = "kubernetes-mcp"
  kubernetes-mcp_namespace = "default"
  kubernetes-mcp_port      = 8080
}

module "kubernetes-mcp" {
  source    = "./modules/kubernetes-mcp"
  name      = local.kubernetes-mcp_name
  namespace = local.kubernetes-mcp_namespace
  images = {
    kubernetes-mcp = {
      repository = "ghcr.io/containers/kubernetes-mcp-server"
      tag        = "v0.0.66@sha256:6d650f4bd6ac303ad82713c997e73a2d001602f9bf17392c9b9a0e30e29c6423" # renovate: datasource=docker depName=ghcr.io/containers/kubernetes-mcp-server
    }
  }
  service_port   = local.kubernetes-mcp_port
  ca_issuer_name = local.cert_issuers.ca_internal
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

module "kubernetes-mcp" {
  source    = "./modules/kubernetes_mcp"
  name      = local.endpoints.kubernetes_mcp.name
  namespace = local.endpoints.kubernetes_mcp.namespace
  images = {
    kubernetes_mcp = local.container_images_digest.kubernetes_mcp
  }
  service_hostname = local.endpoints.kubernetes_mcp.service
  service_port     = local.service_ports.kubernetes_mcp
  ca_issuer_name   = local.kubernetes.cert_issuers.ca_internal
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
    minio_s3_bucket.bucket["fluxcd"],
  ]
}

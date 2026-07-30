# internal registry

module "registry" {
  source    = "./modules/registry"
  name      = local.endpoints.registry.name
  namespace = local.endpoints.registry.namespace
  replicas  = 2
  images = {
    registry = local.container_images_digest.registry
  }
  ca_issuer_name      = local.kubernetes.cert_issuers.ca_internal
  minio_endpoint      = "${local.endpoints.minio.service_ip}:${local.service_ports.minio}" # needs to be reachable and resolvable from host
  minio_bucket        = "registry"
  minio_bucket_prefix = "/"
  minio_user          = minio_iam_user.user["registry"]
  service_port        = local.service_ports.registry
  service_hostname    = local.endpoints.registry.service
  service_ip          = local.endpoints.registry.service_ip
}

resource "minio_s3_object" "fluxcd-registry" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.registry.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "registry/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.bucket["fluxcd"],
  ]
}
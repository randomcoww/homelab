module "sunshine-desktop" {
  source    = "./modules/sunshine-desktop"
  name      = "sunshine-desktop"
  namespace = "default" # must be in same namespace as llama.cpp to share GPU
  images = {
    sunshine-desktop = {
      repository = "zot.cluster.internal/randomcoww/sunshine-desktop"
      tag        = "v2026.516.143833.1788202106@sha256:f1f7f1e8e87e7ee81130b85000a29ae1933d19e2454cb9a2f16e1d94c22e5012" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/sunshine-desktop
    }
    nginx = {
      repository = "docker.io/nginxinc/nginx-unprivileged"
      tag        = "1.31.5-alpine@sha256:aa8c9087d36d93e9d650c5365f883b421e8214aedbad24ade52b844c583358f1" # renovate: datasource=docker depName=docker.io/nginxinc/nginx-unprivileged
    }
  }
  user               = "sunshine"
  uid                = 10000
  storage_class_name = "local-path"
  extra_envs = {
    TZ = local.timezone
  }
  service_hostname = local.endpoints.sunshine.hostname
  ingress_hostname = local.endpoints.sunshine-admin.hostname
  gateway_ref = {
    name      = local.services.cilium.name
    namespace = local.services.cilium.namespace
  }
  auth_backend_ref = {
    name      = local.authelia_name
    namespace = local.authelia_namespace
    port      = 80
  }
  gpu_resource_claim = local.resource_claims.amd-gpu-gfx1151
}

resource "minio_s3_object" "sunshine-desktop" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.sunshine-desktop.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "sunshine-desktop/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}

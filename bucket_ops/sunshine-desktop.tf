module "sunshine-desktop" {
  source    = "./modules/sunshine-desktop"
  name      = "sunshine-desktop"
  namespace = "default" # must be in same namespace as llama.cpp to share GPU
  images = {
    sunshine-desktop = {
      repository = "zot.cluster.internal/randomcoww/sunshine-desktop"
      tag        = "v2026.516.143833.1788202106@sha256:f1f7f1e8e87e7ee81130b85000a29ae1933d19e2454cb9a2f16e1d94c22e5012"
      # tag        = "v2026.914.233613.1789447566@sha256:41bcb64088b36623cd5bcf61640942c59c21653ff0300efc6a3a616893724cf4" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/sunshine-desktop
    }
    nginx = {
      repository = "docker.io/nginxinc/nginx-unprivileged"
      tag        = "1.31.6-alpine@sha256:b54ac358b83fc6c965793fd271839b4ea4cdb6e99895bb19618cbc2ca152d972" # renovate: datasource=docker depName=docker.io/nginxinc/nginx-unprivileged
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

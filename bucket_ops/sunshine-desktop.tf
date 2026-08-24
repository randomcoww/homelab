module "sunshine-desktop" {
  source    = "./modules/sunshine-desktop"
  name      = "sunshine-desktop"
  namespace = "default"
  images = {
    sunshine-desktop = {
      repository = "reg.cluster.internal/randomcoww/sunshine-desktop"
      tag        = "v2026.516.143833.1787575645@sha256:3f7abd8b7f7b49071627d79d6a090f70b28d7b59feefa0c36b6109123d569e27" # renovate: datasource=docker depName=reg.cluster.internal/randomcoww/sunshine-desktop
    }
    nginx = {
      repository = "docker.io/nginxinc/nginx-unprivileged"
      tag        = "1.31.4-alpine@sha256:901e944d1f4fc2bd077e8f5568b98c1f6f8cdacf6b97a87747c43134a339b9a7" # renovate: datasource=docker depName=docker.io/nginxinc/nginx-unprivileged
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

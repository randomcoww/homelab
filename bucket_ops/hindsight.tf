locals {
  hindsight_name      = "hindsight"
  hindsight_namespace = "ai"
  hindsight_port      = 8888
}

module "hindsight" {
  source    = "./modules/hindsight"
  name      = local.hindsight_name
  namespace = local.hindsight_namespace

  extra_envs = {
    HINDSIGHT_API_LLM_MODEL              = "granite-4-2-3b"
    HINDSIGHT_API_REFLECT_WALL_TIMEOUT   = "600" # default 300
    HINDSIGHT_API_REFLECT_MAX_ITERATIONS = "4"   # default 10
    HINDSIGHT_API_LLM_TIMEOUT            = "600"
  }
  extra_secrets = {
    HINDSIGHT_API_LLM_API_KEY  = random_password.llama-cpp-auth-token.result
    HINDSIGHT_API_LLM_BASE_URL = "https://${local.endpoints.agentgateway.hostname}/v1"
  }
  ca_issuer_name = local.cert_issuers.ca_internal
  service_port   = local.hindsight_port

  ingress_hostname = local.endpoints.hindsight.hostname
  gateway_ref = {
    name      = local.services.cilium.name
    namespace = local.services.cilium.namespace
  }
  auth_backend_ref = {
    name      = local.authelia_name
    namespace = local.authelia_namespace
    port      = 80
  }
}

resource "minio_s3_object" "fluxcd-hindsight" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.hindsight.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "hindsight/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}
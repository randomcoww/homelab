resource "random_password" "hindsight-api-key" {
  length  = 30
  special = false
}

resource "random_password" "hindsight-cp-api-key" {
  length  = 30
  special = false
}

module "hindsight" {
  source    = "./modules/hindsight"
  name      = "hindsight"
  namespace = "ai"

  extra_api_envs = {
    HINDSIGHT_API_LLM_MODEL              = "qwen-3-8-flash-next-none"
    HINDSIGHT_API_LLM_TIMEOUT            = "1800"
    HINDSIGHT_API_REFLECT_LLM_MODEL      = "qwen-3-8-flash-next-medium"
    HINDSIGHT_API_REFLECT_WALL_TIMEOUT   = "1800" # default 300
    HINDSIGHT_API_REFLECT_MAX_ITERATIONS = "4"    # default 10
    HINDSIGHT_API_TENANT_EXTENSION       = "hindsight_api.extensions.builtin.tenant:ApiKeyTenantExtension"
    HINDSIGHT_API_MCP_ENABLED            = "true"
    HINDSIGHT_API_MCP_STATELESS          = "true"
  }
  extra_api_secrets = {
    HINDSIGHT_API_LLM_API_KEY    = random_password.llama-cpp-api-key.result
    HINDSIGHT_API_LLM_BASE_URL   = "https://${local.endpoints.agentgateway.hostname}/v1"
    HINDSIGHT_API_TENANT_API_KEY = random_password.hindsight-api-key.result
  }
  extra_controlplane_secrets = {
    HINDSIGHT_CP_DATAPLANE_API_KEY = random_password.hindsight-api-key.result
    HINDSIGHT_CP_ACCESS_KEY        = random_password.hindsight-cp-api-key.result
  }
  ca_issuer_name = local.cert_issuers.ca_internal
  gateway_ref = {
    name      = "${local.services.cilium.name}-cluster"
    namespace = local.services.cilium.namespace
  }
  ingress_hostname = local.endpoints.hindsight.hostname
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

# hindsight admin

output "hindsight" {
  value     = random_password.hindsight-cp-api-key.result
  sensitive = true
}
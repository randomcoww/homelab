locals {
  hindsight_name      = "hindsight"
  hindsight_namespace = "ai"
  hindsight_port      = 8888
}

module "hindsight" {
  source    = "./modules/hindsight"
  name      = "hindsight"
  namespace = "ai"

  extra_envs = {
    HINDSIGHT_API_LLM_MODEL = "granite-4-2-3b"
  }
  extra_secrets = {
    HINDSIGHT_API_LLM_API_KEY  = random_password.llama-cpp-auth-token.result
    HINDSIGHT_API_LLM_BASE_URL = "https://${local.endpoints.llama-cpp.hostname}/v1"
  }
  ca_issuer_name = local.cert_issuers.ca_internal
  service_port   = local.hindsight_port
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
locals {
  kagent_name      = "kagent"
  kagent_namespace = "kagent"
}

module "kagent" {
  source             = "./modules/kagent"
  name               = local.kagent_name
  namespace          = local.kagent_namespace
  ca_issuer_name     = local.cert_issuers.ca_internal
  oidc_client_id     = local.authelia_oidc_clients.kagent.client_id
  oidc_client_secret = local.authelia_oidc_clients.kagent.client_secret
  oidc_scopes        = local.authelia_oidc_clients.kagent.scopes
  oidc_issuer_url    = "https://${local.endpoints.authelia.hostname}"
  ingress_hostname   = local.endpoints.kagent.hostname
  openai_endpoint    = local.endpoints.agentgateway.hostname
  openai_apikey      = random_password.llama-cpp-api-key.result
  gateway_ref = {
    name      = local.services.cilium.name
    namespace = local.services.cilium.namespace
  }
}

resource "minio_s3_object" "fluxcd-kagent" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.kagent.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "kagent/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}
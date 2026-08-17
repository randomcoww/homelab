# Cert-manager with CRDs installed in bootstrap

locals {
  cert_issuers = {
    acme_prod   = "letsencrypt-prod"
    ca_internal = "internal"
  }
}

module "cert-manager-issuer-acme-prod-secret" {
  source    = "../modules/secret"
  name      = local.cert_issuers.acme_prod
  namespace = local.services.cert-manager.namespace
  app       = "cert-issuer"
  release   = "0.1.0"
  data = merge({
    "tls.key"        = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.private_key_pem)
    cloudflare-token = data.terraform_remote_state.sr.outputs.cloudflare_dns_api_token
  })
}

module "cert-manager-issuer-ca-internal-secret" {
  source    = "../modules/secret"
  name      = local.cert_issuers.ca_internal
  namespace = local.services.cert-manager.namespace
  app       = "cert-issuer"
  release   = "0.1.0"
  data = merge({
    "tls.crt" = chomp(data.terraform_remote_state.host.outputs.internal_ca.cert_pem)
    "tls.key" = chomp(data.terraform_remote_state.host.outputs.internal_ca.private_key_pem)
  })
}

resource "minio_s3_object" "fluxcd-cert-manager-crs" {
  for_each = {
    "manifest.yaml" = join("\n---\n", concat([
      for _, m in [
        # letsencrypt prod
        {
          apiVersion = "cert-manager.io/v1"
          kind       = "ClusterIssuer"
          metadata = {
            name = local.cert_issuers.acme_prod
          }
          spec = {
            acme = {
              server = "https://acme-v02.api.letsencrypt.org/directory"
              email  = data.terraform_remote_state.sr.outputs.letsencrypt.username
              privateKeySecretRef = {
                name = module.cert-manager-issuer-acme-prod-secret.name
              }
              disableAccountKeyGeneration = true
              solvers = [
                {
                  dns01 = {
                    cloudflare = {
                      apiTokenSecretRef = {
                        name = module.cert-manager-issuer-acme-prod-secret.name
                        key  = "cloudflare-token"
                      }
                    }
                  }
                  selector = {
                    dnsZones = [
                      local.domains.public,
                    ]
                  }
                },
              ]
            }
          }
        },

        # internal CA
        {
          apiVersion = "cert-manager.io/v1"
          kind       = "ClusterIssuer"
          metadata = {
            name = local.cert_issuers.ca_internal
          }
          spec = {
            ca = {
              secretName = module.cert-manager-issuer-ca-internal-secret.name
            }
          }
        },
      ] :
      yamlencode(m)
      ], [
      module.cert-manager-issuer-acme-prod-secret.manifest,
      module.cert-manager-issuer-ca-internal-secret.manifest,
    ]))
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "cert-manager-crs/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}
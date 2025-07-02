# cert-manager #

module "cert-manager-cloudflare-secret" {
  source  = "../modules/secret"
  name    = "cloudflare-token"
  app     = "cert-issuer"
  release = "0.1.0"
  data = merge({
    token = data.terraform_remote_state.sr.outputs.cloudflare_dns_api_token
  })
}

module "cert-manager-issuer-prod-secret" {
  source  = "../modules/secret"
  name    = local.kubernetes.cert_issuer_prod
  app     = "cert-issuer"
  release = "0.1.0"
  data = merge({
    "tls.key" = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.private_key_pem)
  })
}

module "cert-manager-issuer-staging-secret" {
  source  = "../modules/secret"
  name    = local.kubernetes.cert_issuer_staging
  app     = "cert-issuer"
  release = "0.1.0"
  data = merge({
    "tls.key" = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.staging_private_key_pem)
  })
}

resource "helm_release" "cert-manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  timeout          = 600
  version          = "v1.18.2"
  max_history      = 2
  values = [
    yamlencode({
      deploymentAnnotations = {
        "certmanager.k8s.io/disable-validation" = "true"
      }
      installCRDs = true
      prometheus = {
        enabled = false
      }
      extraArgs = [
        "--dns01-recursive-nameservers-only",
        "--dns01-recursive-nameservers=${local.upstream_dns.ip}:53",
      ]
      podDnsConfig = {
        options = [
          {
            name  = "ndots"
            value = "2"
          },
        ]
      }
    }),
  ]
}

resource "helm_release" "cert-issuer" {
  name        = "cert-issuer"
  chart       = "../helm-wrapper"
  namespace   = "cert-manager"
  wait        = false
  max_history = 2
  values = [
    yamlencode({
      manifests = [
        module.cert-manager-cloudflare-secret.manifest,
        module.cert-manager-issuer-prod-secret.manifest,
        module.cert-manager-issuer-staging-secret.manifest,
        yamlencode({
          apiVersion = "cert-manager.io/v1"
          kind       = "ClusterIssuer"
          metadata = {
            name = local.kubernetes.cert_issuer_prod
          }
          spec = {
            acme = {
              server = "https://acme-v02.api.letsencrypt.org/directory"
              email  = data.terraform_remote_state.sr.outputs.letsencrypt.username
              privateKeySecretRef = {
                name = local.kubernetes.cert_issuer_prod
              }
              disableAccountKeyGeneration = true
              solvers = [
                {
                  dns01 = {
                    cloudflare = {
                      apiTokenSecretRef = {
                        name = "cloudflare-token"
                        key  = "token"
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
        }),
        yamlencode({
          apiVersion = "cert-manager.io/v1"
          kind       = "ClusterIssuer"
          metadata = {
            name = local.kubernetes.cert_issuer_staging
          }
          spec = {
            acme = {
              server = "https://acme-staging-v02.api.letsencrypt.org/directory"
              email  = data.terraform_remote_state.sr.outputs.letsencrypt.username
              privateKeySecretRef = {
                name = local.kubernetes.cert_issuer_staging
              }
              disableAccountKeyGeneration = true
              solvers = [
                {
                  dns01 = {
                    cloudflare = {
                      apiTokenSecretRef = {
                        name = "cloudflare-token"
                        key  = "token"
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
        }),
      ]
    }),
  ]
}

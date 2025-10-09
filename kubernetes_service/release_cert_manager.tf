module "cert-manager-cloudflare-secret" {
  source  = "../modules/secret"
  name    = "cloudflare-token"
  app     = "cert-issuer"
  release = "0.1.0"
  data = merge({
    token = data.terraform_remote_state.sr.outputs.cloudflare_dns_api_token
  })
}

module "cert-manager-issuer-acme-prod-secret" {
  source  = "../modules/secret"
  name    = local.kubernetes.cert_issuers.acme_prod
  app     = "cert-issuer"
  release = "0.1.0"
  data = merge({
    "tls.key" = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.private_key_pem)
  })
}

module "cert-manager-issuer-acme-staging-secret" {
  source  = "../modules/secret"
  name    = local.kubernetes.cert_issuers.acme_staging
  app     = "cert-issuer"
  release = "0.1.0"
  data = merge({
    "tls.key" = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.staging_private_key_pem)
  })
}

module "cert-manager-issuer-ca-internal-secret" {
  source  = "../modules/secret"
  name    = local.kubernetes.cert_issuers.ca_internal
  app     = "cert-issuer"
  release = "0.1.0"
  data = merge({
    "tls.crt" = chomp(data.terraform_remote_state.sr.outputs.trust.ca.cert_pem)
    "tls.key" = chomp(data.terraform_remote_state.sr.outputs.trust.ca.private_key_pem)
  })
}

resource "helm_release" "cert-manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "v1.19.0"
  max_history      = 2
  values = [
    yamlencode({
      replicaCount = 2
      deploymentAnnotations = {
        "certmanager.k8s.io/disable-validation" = "true"
      }
      installCRDs               = true
      enableCertificateOwnerRef = true
      prometheus = {
        enabled = true
      }
      webhook = {
        replicaCount = 2
      }
      cainjector = {
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
/*
resource "helm_release" "cert-manager-csi-driver" {
  name             = "cert-manager-csi-driver"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager-csi-driver"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "v0.11.0"
  max_history      = 2
  values = [
    yamlencode({
      metrics = {
        enabled = true
        port    = local.service_ports.metrics
      }
      podAnnotations = {
        "prometheus.io/scrape" = "true"
        "prometheus.io/port"   = tostring(local.service_ports.metrics)
      }
    }),
  ]
}
*/
resource "helm_release" "trust-manager" {
  name             = "trust-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "trust-manager"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "v0.19.0"
  max_history      = 2
  values = [
    yamlencode({
      replicaCount = 2
      app = {
        trust = {
          namespace = "cert-manager"
        }
        metrics = {
          port = local.service_ports.metrics
        }
      }
      commonAnnotations = {
        "prometheus.io/scrape" = "true"
        "prometheus.io/port"   = tostring(local.service_ports.metrics)
      }
    }),
  ]
}

resource "helm_release" "cert-issuer" {
  name          = "cert-issuer"
  chart         = "../helm-wrapper"
  namespace     = "cert-manager"
  wait          = false
  wait_for_jobs = false
  max_history   = 2
  values = [
    yamlencode({
      manifests = [
        module.cert-manager-cloudflare-secret.manifest, # DNS update for ACME
        module.cert-manager-issuer-acme-prod-secret.manifest,
        module.cert-manager-issuer-acme-staging-secret.manifest,
        module.cert-manager-issuer-ca-internal-secret.manifest,

        # letsencrypt prod
        yamlencode({
          apiVersion = "cert-manager.io/v1"
          kind       = "ClusterIssuer"
          metadata = {
            name = local.kubernetes.cert_issuers.acme_prod
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

        # letsencrypt staging
        yamlencode({
          apiVersion = "cert-manager.io/v1"
          kind       = "ClusterIssuer"
          metadata = {
            name = local.kubernetes.cert_issuers.acme_staging
          }
          spec = {
            acme = {
              server = "https://acme-staging-v02.api.letsencrypt.org/directory"
              email  = data.terraform_remote_state.sr.outputs.letsencrypt.username
              privateKeySecretRef = {
                name = module.cert-manager-issuer-acme-staging-secret.name
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

        # internal CA
        yamlencode({
          apiVersion = "cert-manager.io/v1"
          kind       = "ClusterIssuer"
          metadata = {
            name = local.kubernetes.cert_issuers.ca_internal
          }
          spec = {
            ca = {
              secretName = module.cert-manager-issuer-ca-internal-secret.name
            }
          }
        }),

        # trust manager bundle including internal CA
        yamlencode({
          apiVersion = "trust.cert-manager.io/v1alpha1"
          kind       = "Bundle"
          metadata = {
            name = local.kubernetes.ca_bundle_configmap
          }
          spec = {
            sources = [
              {
                useDefaultCAs = true
              },
              {
                secret = {
                  name = module.cert-manager-issuer-ca-internal-secret.name
                  key  = "tls.crt"
                }
              },
            ]
            target = {
              configMap = {
                key = "ca.crt"
              }
            }
          }
        }),
      ]
    }),
  ]
}

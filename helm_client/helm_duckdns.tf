locals {
  cert_issuer_duckdns_prod    = "letsencrypt-duckdns-prod"
  cert_issuer_duckdns_staging = "letsencrypt-duckdns-staging"
}

# duckdns #

resource "helm_release" "cert-manager-duckdns" {
  name       = "cert-manager-duckdns"
  repository = "https://joshuakraitberg.github.io/helm-charts/"
  chart      = "cert-manager-webhook-duckdns"
  namespace        = "cert-manager"
  create_namespace = true
  wait       = false
  version    = "1.4.2"
  values = [
    yamlencode({
      certManager = {
        namespace = "cert-manager"
        serviceAccountName = "cert-manager"
      }
      clusterIssuer = {
        staging = {
          create = false
        }
        production = {
          create = false
        }
      }
      secret = {
        existingSecret = true
        existingSecretName = "duckdns-token"
      }
    }),
  ]
  depends_on = [
    helm_release.cert-manager,
  ]
}

resource "helm_release" "duckdns-token" {
  name             = "duckdns-token"
  repository       = "https://randomcoww.github.io/repos/helm/"
  chart            = "helm-wrapper"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  version          = "0.1.0"
  values = [
    yamlencode({
      manifests = [
        {
          apiVersion = "v1"
          kind       = "Secret"
          metadata = {
            name = "duckdns-token"
          }
          stringData = {
            token = "7146f0ec-bcc7-46be-bf9c-cac827221e68"
          }
          type = "Opaque"
        },
      ]
    }),
  ]
}

resource "helm_release" "cert-issuer-duckdns" {
  name       = "cert-issuer-duckdns"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "helm-wrapper"
  wait       = false
  version    = "0.1.0"
  values = [
    yamlencode({
      manifests = [
        {
          apiVersion = "cert-manager.io/v1"
          kind       = "ClusterIssuer"
          metadata = {
            name = local.cert_issuer_duckdns_prod
          }
          spec = {
            acme = {
              server = "https://acme-v02.api.letsencrypt.org/directory"
              email  = var.letsencrypt.email
              preferredChain = "ISRG Root X1"
              privateKeySecretRef = {
                name = local.cert_issuer_prod
              }
              disableAccountKeyGeneration = true
              solvers = [
                {
                  dns01 = {
                    webhook = {
                      config = {
                        apiTokenSecretRef = {
                          name = "duckdns-token"
                          key  = "token"
                        }
                      }
                      groupName = "acow.duckdns.org"
                      solverName = "duckdns"
                    }
                  }
                  selector = {
                    dnsZones = [
                      "acow.duckdns.org",
                    ]
                  }
                },
              ]
            }
          }
        },
        {
          apiVersion = "cert-manager.io/v1"
          kind       = "ClusterIssuer"
          metadata = {
            name = local.cert_issuer_duckdns_staging
          }
          spec = {
            acme = {
              server = "https://acme-staging-v02.api.letsencrypt.org/directory"
              email  = var.letsencrypt.email
              preferredChain = "ISRG Root X1"
              privateKeySecretRef = {
                name = local.cert_issuer_staging
              }
              disableAccountKeyGeneration = true
              solvers = [
                {
                  dns01 = {
                    webhook = {
                      config = {
                        apiTokenSecretRef = {
                          name = "duckdns-token"
                          key  = "token"
                        }
                      }
                      groupName = "acow.duckdns.org"
                      solverName = "duckdns"
                    }
                  }
                  selector = {
                    dnsZones = [
                      "acow.duckdns.org",
                    ]
                  }
                },
              ]
            }
          }
        },
      ]
    }),
  ]
  depends_on = [
    helm_release.cert-manager,
    helm_release.cert-issuer-secrets,
  ]
  lifecycle {
    replace_triggered_by = [
      helm_release.cert-manager,
      helm_release.cert-issuer-secrets,
    ]
  }
}
# nginx ingress #

resource "helm_release" "ingress-nginx" {
  for_each = local.ingress_classes

  name             = each.value
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = split(".", local.kubernetes_service_endpoints[each.key])[1]
  create_namespace = true
  wait             = false
  version          = "4.6.1"
  values = [
    yamlencode({
      controller = {
        kind = "DaemonSet"
        ingressClassResource = {
          enabled         = true
          name            = each.value
          controllerValue = "k8s.io/${each.value}"
        }
        ingressClass = each.value
        service = {
          type = "LoadBalancer"
          externalIPs = [
            local.services[each.key].ip,
          ]
          # externalTrafficPolicy = "Local"
        }
        config = {
          ignore-invalid-headers = "off"
          proxy-body-size        = 0
          proxy-buffering        = "off"
          ssl-redirect           = "true"
          use-forwarded-headers  = "true"
        }
      }
    }),
  ]
}

resource "helm_release" "cloudflare-token" {
  name             = "cloudflare-token"
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
            name = "cloudflare-token"
          }
          stringData = {
            token = data.terraform_remote_state.sr.outputs.cloudflare_dns_api_token
          }
          type = "Opaque"
        },
      ]
    }),
  ]
}

# cloudflare tunnel #
/*
resource "helm_release" "cloudflare-tunnel" {
  name       = "cloudflare-tunnel"
  namespace  = "default"
  repository = "https://cloudflare.github.io/helm-charts/"
  chart      = "cloudflare-tunnel"
  wait       = false
  version    = "0.2.0"
  values = [
    yamlencode({
      cloudflare = {
        account    = var.cloudflare.account_id
        tunnelName = cloudflare_tunnel.homelab.name
        tunnelId   = cloudflare_tunnel.homelab.id
        secret     = cloudflare_tunnel.homelab.secret
        ingress = [
          {
            hostname = "*.${local.domains.internal}"
            service  = "https://${local.kubernetes_service_endpoints.ingress_nginx_external}"
          },
        ]
      }
      image = {
        repository = split(":", local.container_images.cloudflared)[0]
        tag        = split(":", local.container_images.cloudflared)[1]
      }
    }),
  ]
}
*/
# cert-manager #

resource "helm_release" "cert-manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = false
  version          = "1.12.1"
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
    }),
  ]
}

resource "helm_release" "cert-issuer-secrets" {
  name             = "cert-issuer-secrets"
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
            name = local.cert_issuer_prod
          }
          stringData = {
            "tls.key" = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.private_key_pem)
          }
          type = "Opaque"
        },
        {
          apiVersion = "v1"
          kind       = "Secret"
          metadata = {
            name = local.cert_issuer_staging
          }
          stringData = {
            "tls.key" = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.staging_private_key_pem)
          }
          type = "Opaque"
        },
      ]
    }),
  ]
}

resource "helm_release" "cert-issuer" {
  name       = "cert-issuer"
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
            name = local.cert_issuer_prod
          }
          spec = {
            acme = {
              server = "https://acme-v02.api.letsencrypt.org/directory"
              email  = var.letsencrypt.email
              privateKeySecretRef = {
                name = local.cert_issuer_prod
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
                      local.domains.internal,
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
            name = local.cert_issuer_staging
          }
          spec = {
            acme = {
              server = "https://acme-staging-v02.api.letsencrypt.org/directory"
              email  = var.letsencrypt.email
              privateKeySecretRef = {
                name = local.cert_issuer_staging
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
                      local.domains.internal,
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

# authelia #

resource "helm_release" "authelia" {
  name      = split(".", local.kubernetes_service_endpoints.authelia)[0]
  namespace = split(".", local.kubernetes_service_endpoints.authelia)[1]
  chart     = "${path.module}/output/charts/authelia"
  wait      = false
}
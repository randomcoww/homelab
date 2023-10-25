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

resource "helm_release" "authelia-users" {
  name             = "authelia-users"
  repository       = "https://randomcoww.github.io/repos/helm/"
  chart            = "helm-wrapper"
  namespace        = "authelia"
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
            name = "authelia-users"
          }
          type = "Opaque"
          stringData = {
            "users_database.yml" = yamlencode({
              users = {
                for email, user in var.authelia_users :
                email => merge({
                  email       = email
                  displayname = email
                }, user)
              }
            })
          }
        },
      ]
    }),
  ]
}

resource "helm_release" "authelia" {
  name      = split(".", local.kubernetes_service_endpoints.authelia)[0]
  namespace = split(".", local.kubernetes_service_endpoints.authelia)[1]
  # repository       = "https://charts.authelia.com"
  ## forked chart for litestream sqlite backup
  repository       = "https://randomcoww.github.io/repos/helm/"
  chart            = "authelia"
  create_namespace = true
  wait             = false
  version          = "0.8.57"
  values = [
    yamlencode({
      domain = local.domains.internal
      ## forked chart params
      backup = {
        image           = local.container_images.litestream
        accessKeyID     = data.terraform_remote_state.sr.outputs.s3.authelia.access_key_id
        secretAccessKey = data.terraform_remote_state.sr.outputs.s3.authelia.secret_access_key
        s3Resource      = "${data.terraform_remote_state.sr.outputs.s3.authelia.resource}/db.sqlite3"
      }
      ##
      ingress = {
        enabled = true
        annotations = {
          "cert-manager.io/cluster-issuer" = local.cert_issuer_prod
        }
        certManager = true
        className   = local.ingress_classes.ingress_nginx_external
        subdomain   = split(".", local.kubernetes_ingress_endpoints.auth)[0]
        tls = {
          enabled = true
          secret  = local.tls_wildcard.secretName
        }
      }
      pod = {
        replicas = 1
        kind     = "Deployment"
        extraVolumeMounts = [
          {
            name      = "authelia-users"
            mountPath = "/config/users_database.yml"
            subPath   = "users_database.yml"
          },
        ]
        extraVolumes = [
          {
            name = "authelia-users"
            secret = {
              secretName = "authelia-users"
            }
          },
        ]
      }
      configMap = {
        telemetry = {
          metrics = {
            enabled = false
          }
        }
        default_redirection_url = "https://${local.kubernetes_ingress_endpoints.auth}"
        default_2fa_method      = "totp"
        theme                   = "dark"
        totp = {
          disable = false
        }
        webauthn = {
          disable = true
        }
        duo_api = {
          disable = true
        }
        authentication_backend = {
          password_reset = {
            disable = true
          }
          ldap = {
            enabled = false
          }
          file = {
            enabled = true
            path    = "/config/users_database.yml"
          }
        }
        session = {
          inactivity           = "1h"
          expiration           = "1h"
          remember_me_duration = 0
          redis = {
            enabled = false
          }
        }
        regulation = {
          max_retries = 4
        }
        storage = {
          local = {
            enabled = true
          }
          mysql = {
            enabled = false
          }
          postgres = {
            enabled = false
          }
        }
        notifier = {
          disable_startup_check = true
          smtp = {
            enabled       = true
            enabledSecret = true
            host          = var.smtp.host
            port          = var.smtp.port
            username      = var.smtp.username
            sender        = var.smtp.username
          }
        }
        access_control = {
          default_policy = "two_factor"
          rules = [
            {
              domain    = local.kubernetes_ingress_endpoints.vaultwarden
              resources = ["^/admin.*"]
              policy    = "two_factor"
            },
            {
              domain = local.kubernetes_ingress_endpoints.vaultwarden
              policy = "bypass"
            },
          ]
        }
      }
      secret = {
        storageEncryptionKey = {
          value = data.terraform_remote_state.sr.outputs.authelia.storage_secret
        }
        smtp = {
          value = var.smtp.password
        }
      }
      persistence = {
        enabled = false
      }
    }),
  ]
  depends_on = [
    helm_release.authelia-users,
  ]
  lifecycle {
    replace_triggered_by = [
      helm_release.authelia-users,
    ]
  }
}

# tailscale #
/*
resource "helm_release" "tailscale" {
  name             = "tailscale"
  namespace        = "tailscale"
  repository       = "https://randomcoww.github.io/repos/helm/"
  chart            = "tailscale"
  create_namespace = true
  wait             = false
  version          = "0.1.6"
  values = [
    yamlencode({
      images = {
        tailscale = local.container_images.tailscale
      }
      authKey    = var.tailscale.auth_key
      kubeSecret = "tailscale-state"
      additionalParameters = {
        TS_ACCEPT_DNS = false
        TS_EXTRA_ARGS = [
          "--advertise-exit-node",
        ]
        TS_ROUTES = [
          local.networks.lan.prefix,
          local.networks.service.prefix,
          local.networks.kubernetes.prefix,
          local.networks.kubernetes_service.prefix,
          local.networks.kubernetes_pod.prefix,
        ]
      }
    }),
  ]
}
*/

# tailscale with ssm secret #
resource "helm_release" "tailscale-ssm" {
  name             = "tailscale-ssm"
  namespace        = "tailscale"
  repository       = "https://randomcoww.github.io/repos/helm/"
  chart            = "tailscale"
  create_namespace = true
  wait             = false
  version          = "0.1.9"
  values = [
    yamlencode({
      images = {
        tailscale = local.container_images.tailscale
      }
      authKey = var.tailscale.auth_key
      ssm = {
        awsRegion       = data.terraform_remote_state.sr.outputs.ssm.tailscale.aws_region
        accessKeyID     = data.terraform_remote_state.sr.outputs.ssm.tailscale.access_key_id
        secretAccessKey = data.terraform_remote_state.sr.outputs.ssm.tailscale.secret_access_key
        resource        = data.terraform_remote_state.sr.outputs.ssm.tailscale.resource
      }
      additionalParameters = {
        TS_ACCEPT_DNS = false
        TS_EXTRA_ARGS = [
          "--advertise-exit-node",
        ]
        TS_ROUTES = [
          local.networks.lan.prefix,
          local.networks.service.prefix,
          local.networks.kubernetes.prefix,
          local.networks.kubernetes_service.prefix,
          local.networks.kubernetes_pod.prefix,
        ]
      }
    }),
  ]
}
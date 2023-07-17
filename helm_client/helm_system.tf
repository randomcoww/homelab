# basic system #

resource "helm_release" "cluster-services" {
  name       = "cluster-services"
  namespace  = "kube-system"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "cluster-services"
  wait       = false
  version    = "0.2.5"
  values = [
    yamlencode({
      images = {
        flannelCNIPlugin = local.container_images.flannel_cni_plugin
        flannel          = local.container_images.flannel
        kapprover        = local.container_images.kapprover
        kubeProxy        = local.container_images.kube_proxy
      }
      ports = {
        kubeProxy = local.ports.kube_proxy
        apiServer = local.ports.apiserver
      }
      apiServerIP      = local.services.apiserver.ip
      cniInterfaceName = local.kubernetes.cni_bridge_interface_name
      podNetworkPrefix = local.networks.kubernetes_pod.prefix
      internalDomain   = local.domains.internal
    }),
  ]
}

# coredns #

resource "helm_release" "kube-dns" {
  name       = "kube-dns"
  namespace  = "kube-system"
  repository = "https://coredns.github.io/helm"
  chart      = "coredns"
  wait       = false
  version    = "1.22.0"
  values = [
    yamlencode({
      image = {
        repository = split(":", local.container_images.coredns)[0]
        tag        = split(":", local.container_images.coredns)[1]
      }
      replicaCount = 2
      serviceType  = "ClusterIP"
      serviceAccount = {
        create = false
      }
      service = {
        clusterIP = local.services.cluster_dns.ip
      }
      affinity = {
        podAntiAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = [
            {
              labelSelector = {
                matchExpressions = [
                  {
                    key      = "app"
                    operator = "In"
                    values = [
                      "kube-dns",
                    ]
                  },
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            },
          ]
        }
      }
      priorityClassName = "system-cluster-critical"
      servers = [
        {
          zones = [
            {
              zone = "."
            },
          ]
          port = 53
          plugins = [
            {
              name = "health"
            },
            {
              name = "ready"
            },
            {
              name        = "kubernetes"
              parameters  = "${local.domains.kubernetes} in-addr.arpa ip6.arpa"
              configBlock = <<EOF
pods insecure
fallthrough in-addr.arpa ip6.arpa
ttl 30
EOF
            },
            # cert-manager uses to verify resources internally
            {
              name       = "forward"
              parameters = "${local.domains.internal} dns://${local.services.cluster_external_dns.ip}"
            },
            {
              name        = "forward"
              parameters  = ". tls://${local.upstream_dns.ip}"
              configBlock = <<EOF
tls_servername ${local.upstream_dns.tls_servername}
health_check 5s
EOF
            },
            {
              name       = "cache"
              parameters = 30
            },
          ]
        },
      ]
    }),
  ]
}

# coredns with external-dns #

resource "helm_release" "external-dns" {
  name       = "external-dns"
  namespace  = "kube-system"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "external-dns"
  wait       = false
  version    = "0.1.15"
  values = [
    yamlencode({
      mode           = "DaemonSet"
      internalDomain = local.domains.internal
      images = {
        coreDNS     = local.container_images.coredns
        externalDNS = local.container_images.external_dns
        etcd        = local.container_images.etcd
      }
      serviceAccount = {
        create = true
        name   = "external-dns"
      }
      hostNetwork = {
        enabled = false
      }
      priorityClassName = "system-cluster-critical"
      dataSources = [
        "service",
        "ingress",
      ]
      service = {
        type      = "LoadBalancer"
        clusterIP = local.services.cluster_external_dns.ip
        externalIPs = [
          local.services.external_dns.ip,
        ]
      }
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "kubernetes.io/hostname"
                    operator = "In"
                    values = [
                      for _, member in local.members.gateway :
                      member.hostname
                    ]
                  },
                  {
                    key      = "kubernetes.io/hostname"
                    operator = "In"
                    values = [
                      for _, member in local.members.vrrp :
                      member.hostname
                    ]
                  },
                ]
              },
            ]
          }
        }
      }
      coreDNSLivenessProbe = {
        httpGet = {
          path   = "/health"
          port   = 8080
          scheme = "HTTP"
        }
        initialDelaySeconds = 30
        periodSeconds       = 10
        timeoutSeconds      = 5
        failureThreshold    = 5
        successThreshold    = 1
      }
      coreDNSReadinessProbe = {
        httpGet = {
          path   = "/ready"
          port   = 8181
          scheme = "HTTP"
        }
        initialDelaySeconds = 30
        periodSeconds       = 10
        timeoutSeconds      = 5
        failureThreshold    = 5
        successThreshold    = 1
      }
      servers = [
        {
          zones = [
            {
              zone = "."
            },
          ]
          port = local.ports.gateway_dns
          plugins = [
            {
              name = "health"
            },
            {
              name = "ready"
            },
            {
              name        = "etcd"
              parameters  = "${local.domains.internal} in-addr.arpa ip6.arpa"
              configBlock = <<EOF
fallthrough
EOF
            },
            {
              name        = "forward"
              parameters  = ". tls://${local.upstream_dns.ip}"
              configBlock = <<EOF
tls_servername ${local.upstream_dns.tls_servername}
health_check 5s
EOF
            },
            {
              name       = "cache"
              parameters = 30
            },
          ]
        },
      ]
    }),
  ]
}

# nginx ingress #

resource "helm_release" "nginx-ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = split(".", local.kubernetes_service_endpoints.nginx)[1]
  create_namespace = true
  wait             = false
  version          = "4.6.1"
  values = [
    yamlencode({
      controller = {
        kind = "DaemonSet"
        ingressClassResource = {
          enabled = true
          name    = "nginx"
        }
        ingressClass = "nginx"
        service = {
          type = "LoadBalancer"
          externalIPs = [
            local.services.external_ingress.ip,
          ]
          # externalTrafficPolicy = "Local"
        }
        config = {
          ignore-invalid-headers = "off"
          proxy-body-size        = 0
          proxy-buffering        = "off"
          ssl-redirect           = "true"
        }
      }
    }),
  ]
}

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
        "--dns01-recursive-nameservers=${local.upstream_dns_ip}:53",
      ]
    }),
  ]
}

resource "null_resource" "letsencrypt-id" {
  triggers = {
    id = var.letsencrypt.email
  }
}

resource "tls_private_key" "letsencrypt-prod" {
  algorithm = "RSA"
  rsa_bits  = 4096
  lifecycle {
    replace_triggered_by = [
      null_resource.letsencrypt-id,
    ]
  }
}

resource "tls_private_key" "letsencrypt-staging" {
  algorithm = "RSA"
  rsa_bits  = 4096
  lifecycle {
    replace_triggered_by = [
      null_resource.letsencrypt-id,
    ]
  }
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
            "tls.key" = chomp(tls_private_key.letsencrypt-prod.private_key_pem)
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
            "tls.key" = chomp(tls_private_key.letsencrypt-staging.private_key_pem)
          }
          type = "Opaque"
        },
      ]
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
            token = cloudflare_api_token.dns_edit.value
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
                {
                  http01 = {
                    ingress = {
                      class = "nginx"
                    }
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
                {
                  http01 = {
                    ingress = {
                      class = "nginx"
                    }
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

resource "random_password" "authelia-storage-secret" {
  length  = 64
  special = false
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
        s3Resource      = "${local.authelia.backup_bucket}/${local.authelia.backup_path}/db.sqlite3"
        accessKeyID     = aws_iam_access_key.authelia-backup.id
        secretAccessKey = aws_iam_access_key.authelia-backup.secret
      }
      ##
      ingress = {
        enabled = true
        annotations = {
          "cert-manager.io/cluster-issuer" = local.cert_issuer_prod
        }
        certManager = true
        className   = "nginx"
        subdomain   = split(".", local.kubernetes_ingress_endpoints.auth)[0]
        tls = {
          enabled = true
          secret  = "authelia-tls"
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
          default_policy = "deny"
          rules = [
            {
              domain = local.kubernetes_ingress_endpoints.mpd
              policy = "two_factor"
            },
            {
              domain = local.kubernetes_ingress_endpoints.transmission
              policy = "two_factor"
            },
            {
              domain = local.kubernetes_ingress_endpoints.pl
              policy = "two_factor"
            },
            {
              domain    = local.kubernetes_ingress_endpoints.vaultwarden
              resources = ["^/admin.*"]
              policy    = "two_factor"
            },
            {
              domain = local.kubernetes_ingress_endpoints.vaultwarden
              policy = "bypass"
            },
            {
              domain = local.kubernetes_ingress_endpoints.webdav
              policy = "two_factor"
            },
          ]
        }
      }
      secret = {
        storageEncryptionKey = {
          value = random_password.authelia-storage-secret.result
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

# local-storage storage class #

resource "helm_release" "local-path-provisioner" {
  name       = "local-path-provisioner"
  namespace  = "kube-system"
  repository = "https://charts.containeroo.ch"
  chart      = "local-path-provisioner"
  wait       = false
  version    = "0.0.24"
  values = [
    yamlencode({
      storageClass = {
        name = "local-path"
      }
      nodePathMap = [
        {
          node  = "DEFAULT_PATH_FOR_NON_LISTED_NODES"
          paths = ["${local.mounts.containers_path}/local_path_provisioner"]
        },
      ]
    }),
  ]
}

# openebs #
/*
resource "helm_release" "openebs" {
  name             = "openebs"
  namespace        = "openebs"
  repository       = "https://openebs.github.io/charts"
  chart            = "openebs"
  create_namespace = true
  wait             = false
  version          = "3.6.0"
  values = [
    yamlencode({
      apiserver = {
        enabled = true
        sparse = {
          enabled = true
        }
      }
      localprovisioner = {
        enabled  = true
        basePath = "${local.mounts.containers_path}/openebs/local"
      }
      snapshotOperator = {
        enabled = false
      }
      jiva = {
        enabled            = true
        replicas           = 2
        defaultStoragePath = "${local.mounts.containers_path}/openebs"
      }
      ndmOperator = {
        enabled = false
      }
      ndm = {
        enabled = false
      }
      webhook = {
        enabled = false
      }
      cstor = {
        enabled = false
      }
    }),
  ]
}
*/

# kea #

module "kea-config" {
  source        = "./modules/kea_config"
  resource_name = "kea"
  service_ips = [
    local.services.cluster_kea_primary.ip, local.services.cluster_kea_secondary.ip
  ]
  shared_data_path = "/var/lib/kea"
  kea_peer_port    = local.ports.kea_peer
  ipxe_file_url    = "http://${local.services.matchbox.ip}:${local.ports.matchbox}/boot.ipxe"
  cluster_domain   = local.domains.kubernetes
  networks = [
    for _, network in local.networks :
    {
      prefix = network.prefix
      routers = [
        local.services.gateway.ip,
      ]
      domain_name_servers = [
        local.services.external_dns.ip,
      ]
      tftp_server = local.services.tftp.ip
      mtu         = network.mtu
      pools = [
        cidrsubnet(network.prefix, 1, 1),
      ]
    } if lookup(network, "enable_dhcp_server", false)
  ]
}

resource "helm_release" "tftpd" {
  name       = "tftpd"
  namespace  = "default"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "tftpd"
  wait       = false
  version    = "0.1.1"
  values = [
    yamlencode({
      images = {
        tftpd = local.container_images.tftpd
      }
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "kubernetes.io/hostname"
                    operator = "In"
                    values = [
                      for _, member in local.members.gateway :
                      member.hostname
                    ]
                  },
                  {
                    key      = "kubernetes.io/hostname"
                    operator = "In"
                    values = [
                      for _, member in local.members.vrrp :
                      member.hostname
                    ]
                  },
                ]
              },
            ]
          }
        }
      }
      ports = {
        tftpd = local.ports.pxe_tftp
      }
    }),
  ]
}

resource "helm_release" "kea" {
  name       = "kea"
  namespace  = "default"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "kea"
  wait       = false
  version    = "0.1.15"
  values = [
    yamlencode({
      images = {
        kea = local.container_images.kea
      }
      peers = [
        for _, peer in module.kea-config.config :
        {
          serviceIP       = peer.service_ip
          podName         = peer.pod_name
          dhcp4Config     = peer.dhcp4_config
          ctrlAgentConfig = peer.ctrl_agent_config
        }
      ]
      sharedDataPath = "/var/lib/kea"
      StatefulSet = {
        replicaCount = length(module.kea-config.config)
      }
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "kubernetes.io/hostname"
                    operator = "In"
                    values = [
                      for _, member in local.members.gateway :
                      member.hostname
                    ]
                  },
                ]
              },
            ]
          }
        }
        podAntiAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = [
            {
              labelSelector = {
                matchExpressions = [
                  {
                    key      = "app"
                    operator = "In"
                    values = [
                      "kea",
                    ]
                  },
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            },
          ]
        }
      }
      ports = {
        keaPeer = local.ports.kea_peer
      }
      peerService = {
        port = local.ports.kea_peer
      }
    }),
  ]
}

# matchbox with data sync #

module "matchbox-certs" {
  source        = "./modules/matchbox_certs"
  api_listen_ip = local.services.matchbox.ip
}

module "matchbox-syncthing" {
  source              = "./modules/syncthing_config"
  replica_count       = 3
  resource_name       = "matchbox"
  resource_namespace  = "default"
  service_name        = "matchbox-sync"
  sync_data_paths     = ["/var/tmp/matchbox"]
  syncthing_peer_port = 22000
}

resource "helm_release" "matchbox" {
  name       = "matchbox"
  namespace  = "default"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "matchbox"
  wait       = false
  version    = "0.2.14"
  values = [
    yamlencode({
      images = {
        matchbox  = local.container_images.matchbox
        syncthing = local.container_images.syncthing
      }
      peers = [
        for _, peer in module.matchbox-syncthing.peers :
        {
          podName       = peer.pod_name
          syncthingCert = chomp(peer.cert)
          syncthingKey  = chomp(peer.key)
        }
      ]
      syncthingConfig = module.matchbox-syncthing.config
      matchboxSecret = {
        ca   = chomp(module.matchbox-certs.secret.ca)
        cert = chomp(module.matchbox-certs.secret.cert)
        key  = chomp(module.matchbox-certs.secret.key)
      }
      sharedDataPath = "/var/tmp/matchbox"
      StatefulSet = {
        replicaCount = length(module.matchbox-syncthing.peers)
      }
      affinity = {
        podAntiAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = [
            {
              labelSelector = {
                matchExpressions = [
                  {
                    key      = "app"
                    operator = "In"
                    values = [
                      "matchbox",
                    ]
                  },
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            },
          ]
        }
      }
      ports = {
        matchbox    = local.ports.matchbox
        matchboxAPI = local.ports.matchbox_api
      }
      syncService = {
        port = 22000
      }
      apiService = {
        type = "LoadBalancer"
        port = local.ports.matchbox_api
        externalIPs = [
          local.services.matchbox.ip,
        ]
      }
      service = {
        type = "LoadBalancer"
        port = local.ports.matchbox
        externalIPs = [
          local.services.matchbox.ip,
        ]
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = local.kubernetes_ingress_endpoints.matchbox
        }
      }
    }),
  ]
}

resource "local_file" "matchbox-client-cert" {
  for_each = {
    "matchbox-ca.pem"   = module.matchbox-certs.client.ca
    "matchbox-cert.pem" = module.matchbox-certs.client.cert
    "matchbox-key.pem"  = module.matchbox-certs.client.key
  }

  filename = "./output/certs/${each.key}"
  content  = each.value
}

# minio #

resource "random_password" "minio-access-key-id" {
  length  = 30
  special = false
}

resource "random_password" "minio-secret-access-key" {
  length  = 30
  special = false
}

resource "helm_release" "minio" {
  name             = split(".", local.kubernetes_service_endpoints.minio)[0]
  namespace        = split(".", local.kubernetes_service_endpoints.minio)[1]
  repository       = "https://charts.min.io/"
  chart            = "minio"
  create_namespace = true
  wait             = false
  version          = "5.0.8"
  values = [
    yamlencode({
      clusterDomain = local.domains.kubernetes
      mode          = "distributed"
      rootUser      = random_password.minio-access-key-id.result
      rootPassword  = random_password.minio-secret-access-key.result
      persistence = {
        storageClass = "local-path"
      }
      drivesPerNode = 2
      replicas      = 3
      resources = {
        requests = {
          memory = "8Gi"
        }
      }
      consoleService = {
        type      = "ClusterIP"
        clusterIP = "None"
      }
      service = {
        type = "LoadBalancer"
        port = local.ports.minio
        externalIPs = [
          local.services.minio.ip,
        ]
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = local.kubernetes_ingress_endpoints.minio
        }
      }
      ingress = {
        enabled = false
        # ingressClassName = "nginx"
        # annotations      = local.nginx_ingress_annotations
        # tls = [
        #   {
        #     secretName = "minio-tls"
        #     hosts = [
        #       local.kubernetes_ingress_endpoints.minio,
        #     ]
        #   },
        # ]
        # hosts = [
        #   local.kubernetes_ingress_endpoints.minio,
        # ]
      }
      environment = {
        MINIO_API_REQUESTS_DEADLINE  = "2m"
        MINIO_STORAGE_CLASS_STANDARD = "EC:2"
        MINIO_STORAGE_CLASS_RRS      = "EC:2"
      }
      buckets = [
        for bucket in local.minio_buckets :
        merge(bucket, {
          purge      = false
          versioning = false
        })
      ]
      users          = []
      policies       = []
      customCommands = []
      svcaccts       = []
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "kubernetes.io/hostname"
                    operator = "In"
                    values = [
                      for _, member in local.members.disks :
                      member.hostname
                    ]
                  },
                ]
              },
            ]
          }
        }
        podAntiAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = [
            {
              labelSelector = {
                matchExpressions = [
                  {
                    key      = "app"
                    operator = "In"
                    values = [
                      "minio",
                    ]
                  },
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            },
          ]
        }
      }
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
            service  = "https://${local.kubernetes_service_endpoints.nginx}"
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

# tailscale #

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

# amd device plugin #
/*
resource "helm_release" "amd-gpu" {
  name       = "amd-gpu"
  repository = "https://radeonopencompute.github.io/k8s-device-plugin/"
  chart      = "amd-gpu"
  namespace  = "kube-system"
  wait       = false
  version    = "0.5.0"
  values = [
    yamlencode({
      tolerations = [
        {
          effect   = "NoExecute"
          operator = "Exists"
        },
      ]
    })
  ]
}
*/

# nvidia device plugin #
/*
resource "helm_release" "nvidia-device-plugin" {
  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  namespace  = "kube-system"
  wait       = false
  version    = "0.12.2"
  values = [
    yamlencode({
      tolerations = [
        {
          effect   = "NoExecute"
          operator = "Exists"
        },
      ]
    })
  ]
}
*/
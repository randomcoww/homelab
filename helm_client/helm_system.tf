# basic system #

resource "helm_release" "cluster_services" {
  name       = "cluster-services"
  namespace  = "kube-system"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "cluster-services"
  version    = "0.2.4"
  wait       = false
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

resource "helm_release" "kube_dns" {
  name       = "kube-dns"
  namespace  = "kube-system"
  repository = "https://coredns.github.io/helm"
  chart      = "coredns"
  version    = "1.22.0"
  wait       = false
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
              parameters  = ". tls://${local.upstream_dns_ip}"
              configBlock = <<EOF
tls_servername ${local.upstream_dns_tls_servername}
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

resource "helm_release" "external_dns" {
  name       = "external-dns"
  namespace  = "kube-system"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "external-dns"
  version    = "0.1.15"
  wait       = false
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
        enabled = true
      }
      priorityClassName = "system-cluster-critical"
      dataSources = [
        "service",
        "ingress",
      ]
      service = {
        type      = "ClusterIP"
        clusterIP = local.services.cluster_external_dns.ip
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
          host   = "127.0.0.1"
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
          host   = "127.0.0.1"
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
fallthrough in-addr.arpa ip6.arpa
EOF
            },
            {
              name        = "forward"
              parameters  = ". tls://${local.upstream_dns_ip}"
              configBlock = <<EOF
tls_servername ${local.upstream_dns_tls_servername}
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

resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.6.0"
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
          externalTrafficPolicy = "Local"
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

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "1.11.1"
  wait             = true
  values = [
    yamlencode({
      installCRDs = true
      prometheus = {
        enabled = false
      }
    }),
  ]
}

resource "null_resource" "letsencrypt-id" {
  triggers = {
    id = var.letsencrypt_email
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

resource "helm_release" "cert_issuer_secrets" {
  name             = "cert-issuer"
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
            name = "letsencrypt-prod"
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
            name = "letsencrypt-staging"
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

resource "helm_release" "cert_issuer" {
  name       = "cert-issuer"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "helm-wrapper"
  version    = "0.1.0"
  values = [
    yamlencode({
      manifests = [
        {
          apiVersion = "cert-manager.io/v1"
          kind       = "ClusterIssuer"
          metadata = {
            name = "letsencrypt-prod"
          }
          spec = {
            acme = {
              server = "https://acme-v02.api.letsencrypt.org/directory"
              email  = var.letsencrypt_email
              privateKeySecretRef = {
                name = "letsencrypt-prod"
              }
              disableAccountKeyGeneration = true
              solvers = [
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
            name = "letsencrypt-staging"
          }
          spec = {
            acme = {
              server = "https://acme-staging-v02.api.letsencrypt.org/directory"
              email  = var.letsencrypt_email
              privateKeySecretRef = {
                name = "letsencrypt-staging"
              }
              disableAccountKeyGeneration = true
              solvers = [
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
    helm_release.cert_manager,
    helm_release.cert_issuer_secrets,
  ]
  lifecycle {
    replace_triggered_by = [
      helm_release.cert_manager,
      helm_release.cert_issuer_secrets,
    ]
  }
}

# authelia #

resource "helm_release" "authelia_users" {
  name             = "authelia-users"
  repository       = "https://randomcoww.github.io/repos/helm/"
  chart            = "helm-wrapper"
  namespace        = "authelia"
  create_namespace = true
  version          = "0.1.0"
  wait             = true
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
                for _, user in local.users :
                user.name => merge({
                  displayname = user.name
                }, user.sso)
                if length(keys(user.sso)) > 0
              }
            })
          }
        },
      ]
    })
  ]
}

resource "helm_release" "authelia" {
  name             = split(".", local.kubernetes_service_endpoints.authelia)[0]
  namespace        = split(".", local.kubernetes_service_endpoints.authelia)[1]
  repository       = "https://charts.authelia.com"
  chart            = "authelia"
  create_namespace = true
  version          = "0.8.57"
  wait             = false
  values = [
    yamlencode({
      domain = local.domains.internal
      ingress = {
        enabled = true
        annotations = {
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
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
        access_control = {
          default_policy = "deny"
          networks = [
            {
              name = "whitelist"
              networks = [
                local.networks.lan.prefix,
                local.networks.service.prefix,
                local.networks.kubernetes.prefix,
              ]
            },
          ]
          rules = [
            {
              domain   = local.kubernetes_ingress_endpoints.mpd
              networks = ["whitelist"]
              policy   = "bypass"
            },
            {
              domain = local.kubernetes_ingress_endpoints.mpd
              policy = "one_factor"
            },
            {
              domain = local.kubernetes_ingress_endpoints.transmission
              policy = "one_factor"
            },
            {
              domain = local.kubernetes_ingress_endpoints.pl
              policy = "one_factor"
            },
          ]
        }
        theme = "dark"
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
          filesystem = {
            enabled = true
          }
          smtp = {
            enabled = false
          }
        }
      }
      persistence = {
        enabled = false
      }
    }),
  ]
  depends_on = [
    helm_release.authelia_users,
  ]
  lifecycle {
    replace_triggered_by = [
      helm_release.authelia_users,
    ]
  }
}

# local-storage storage class #

resource "helm_release" "local-path-provisioner" {
  name       = "local-path-provisioner"
  namespace  = "kube-system"
  repository = "https://charts.containeroo.ch"
  chart      = "local-path-provisioner"
  version    = "0.0.24"
  wait       = false
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
  version          = "3.6.0"
  wait             = false
  create_namespace = true
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
        local.services.gateway.ip,
      ]
      tftp_server = local.services.gateway.ip
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
  version    = "0.1.1"
  wait       = false
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
  version    = "0.1.15"
  wait       = false
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
  version    = "0.2.14"
  wait       = false
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
        type = "ClusterIP"
        port = local.ports.matchbox_api
        externalIPs = [
          local.services.matchbox.ip,
        ]
      }
      service = {
        type = "ClusterIP"
        port = local.ports.matchbox
        externalIPs = [
          local.services.matchbox.ip,
        ]
      }
    }),
  ]
}

resource "local_file" "matchbox_client_cert" {
  for_each = {
    "matchbox-ca.pem"   = module.matchbox-certs.client.ca
    "matchbox-cert.pem" = module.matchbox-certs.client.cert
    "matchbox-key.pem"  = module.matchbox-certs.client.key
  }

  filename = "./output/certs/${each.key}"
  content  = each.value
}

# minio with hostNetwork #

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
  version          = "5.0.8"
  wait             = false
  create_namespace = true
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
      minioAPIPort  = local.ports.minio
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
        type = "ClusterIP"
        port = local.ports.minio
        externalIPs = [
          local.services.minio.ip,
        ]
      }
      ingress = {
        enabled = false
        # ingressClassName = "nginx"
        # annotations = {
        #   "cert-manager.io/cluster-issuer"                    = "letsencrypt-prod"
        #   "nginx.ingress.kubernetes.io/proxy-http-version"    = "1.1"
        #   "nginx.ingress.kubernetes.io/proxy-connect-timeout" = 300
        # }
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

output "minio_endpoint" {
  value = {
    version = "10"
    aliases = {
      m = {
        url       = "http://${local.services.minio.ip}:${local.ports.minio}"
        accessKey = nonsensitive(random_password.minio-access-key-id.result)
        secretKey = nonsensitive(random_password.minio-secret-access-key.result)
        api       = "S3v4"
        path      = "auto"
      }
    }
  }
}

# amd device plugin #
/*
resource "helm_release" "amd_gpu" {
  name         = "amd-gpu"
  repository   = "https://radeonopencompute.github.io/k8s-device-plugin/"
  chart        = "amd-gpu"
  namespace    = "kube-system"
  version      = "0.5.0"
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
resource "helm_release" "nvidia_device_plugin" {
  name         = "nvidia-device-plugin"
  repository   = "https://nvidia.github.io/k8s-device-plugin"
  chart        = "nvidia-device-plugin"
  namespace    = "kube-system"
  version      = "0.12.2"
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

# hostapd #

module "hostapd-roaming" {
  source        = "./modules/hostapd_roaming"
  resource_name = "hostapd"
  replica_count = 1
}

resource "helm_release" "hostapd" {
  name       = "hostapd"
  namespace  = "default"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "hostapd"
  version    = "0.1.8"
  wait       = false
  values = [
    yamlencode({
      image = local.container_images.hostapd
      peers = [
        for _, peer in module.hostapd-roaming.peers :
        {
          podName = peer.pod_name
          config = merge({
            # sae_password=
            # ssid=
            # country_code=
            # # one of: 36 44 52 60 100 108 116 124 132 140 149 157 184 192
            # channel=
            # # one of: 42 58 106 122 138 155
            vht_oper_centr_freq_seg0_idx = var.hostapd.channel + 6
            interface                    = "wlan0"
            bridge                       = "br-lan"
            driver                       = "nl80211"
            noscan                       = 1
            preamble                     = 1
            wpa                          = 2
            wpa_key_mgmt                 = "SAE"
            wpa_pairwise                 = "CCMP"
            group_cipher                 = "CCMP"
            hw_mode                      = "a"
            require_ht                   = 1
            require_vht                  = 1
            ieee80211n                   = 1
            ieee80211ax                  = 1
            ieee80211d                   = 1
            ieee80211h                   = 0
            ieee80211w                   = 2
            vht_oper_chwidth             = 1
            ignore_broadcast_ssid        = 0
            auth_algs                    = 1
            wmm_enabled                  = 1
            disassoc_low_ack             = 0
            ap_max_inactivity            = 900
            ht_capab = "[${join("][", [
              "HT40-", "HT40+", "SHORT-GI-20", "SHORT-GI-40",
              "LDPC", "TX-STBC", "RX-STBC1", "MAX-AMSDU-7935",
            ])}]"
            vht_capab = "[${join("][", [
              "RXLDPC", "TX-STBC-2BY1", "RX-STBC-1", "SHORT-GI-80",
              "MAX-MPDU-11454", "MAX-A-MPDU-LEN-EXP3",
              "BF-ANTENNA-1", "SOUNDING-DIMENSION-1", "SU-BEAMFORMEE",
              "BF-ANTENNA-2", "SOUNDING-DIMENSION-2", "MU-BEAMFORMEE",
              "RX-ANTENNA-PATTERN", "TX-ANTENNA-PATTERN",
            ])}]"
            bssid                 = peer.bssid
            mobility_domain       = peer.mobility_domain
            pmk_r1_push           = 1
            ft_psk_generate_local = 1
            r1_key_holder         = peer.r1_key_holder
            nas_identifier        = peer.nas_identifier
            r0kh = [
              for _, p in module.hostapd-roaming.peers :
              "${p.bssid} ${p.nas_identifier} ${p.encryption_key}"
            ]
            r1kh = [
              for _, p in module.hostapd-roaming.peers :
              "${p.bssid} ${p.bssid} ${p.encryption_key}"
            ]
          }, var.hostapd)
        }
      ]
      StatefulSet = {
        replicaCount = length(module.hostapd-roaming.peers)
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
                      for _, member in local.members.desktop :
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
                      "hostapd",
                    ]
                  },
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            },
          ]
        }
      }
      tolerations = [
        {
          key      = "node-role.kubernetes.io/de"
          operator = "Exists"
        },
      ]
    }),
  ]
}

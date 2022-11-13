# basic system #

resource "helm_release" "cluster_services" {
  name       = "cluster-services"
  namespace  = "kube-system"
  repository = "https://randomcoww.github.io/terraform-infra/"
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

# kube-router #

# resource "helm_release" "kube_router" {
#   name       = "kube-router"
#   namespace  = "kube-system"
#   repository = "https://charts.enix.io/"
#   chart      = "kube-router"
#   version    = "1.8.0"
#   wait       = false
#   values = [
#     yamlencode({
#       kubeRouter = {
#         cni = {
#           install = true
#           config = jsonencode({
#             cniVersion = "0.3.0"
#             name       = "kube-router"
#             plugins = [
#               {
#                 name             = "kubernetes"
#                 type             = "bridge"
#                 bridge           = local.kubernetes.cni_bridge_interface_name
#                 isDefaultGateway = true
#                 hairpinMode      = true
#                 ipam = {
#                   type = "host-local"
#                 }
#               },
#               {
#                 type = "portmap"
#                 capabilities = {
#                   snat         = true
#                   portMappings = true
#                 }
#               },
#             ]
#           })
#         }
#         router = {
#           nodesFullMesh           = true
#           enablePodEgress         = true
#           enableOverlay           = true
#           enableIbgp              = true
#           enableCni               = true
#           clusterAsn              = 65000
#           bgpGracefulRestart      = true
#           advertisePodCidr        = true
#           advertiseLoadbalancerIp = true
#           advertiseExternalIp     = true
#           advertiseClusterIp      = true
#         }
#         firewall = {
#           enabled = true
#         }
#         serviceProxy = {
#           enabled                 = true
#           nodeportBindonAllIp     = true
#           masqueradeAll           = true
#           ipvsPermitAll           = true
#           ipvsGracefulTermination = true
#           hairpinMode             = true
#         }
#       }
#     }),
#   ]
# }

# coredns #

resource "helm_release" "kube_dns" {
  name       = "kube-dns"
  namespace  = "kube-system"
  repository = "https://coredns.github.io/helm"
  chart      = "coredns"
  version    = "1.19.5"
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
              zone = "${local.domains.kubernetes}."
            },
          ]
          port = local.ports.gateway_dns
          plugins = [
            {
              name = "errors"
            },
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
            {
              name = "reload"
            },
            {
              name = "loadbalance"
            },
          ]
        },
        {
          zones = [
            {
              zone = "${local.domains.internal}."
            },
          ]
          port = local.ports.gateway_dns
          plugins = [
            {
              name = "errors"
            },
            {
              name = "health"
            },
            {
              name = "ready"
            },
            {
              name       = "forward"
              parameters = ". ${local.services.cluster_external_dns.ip}"
            },
            {
              name = "reload"
            },
            {
              name = "loadbalance"
            },
          ]
        },
        {
          zones = [
            {
              zone = "."
            },
          ]
          port = local.ports.gateway_dns
          plugins = [
            {
              name = "errors"
            },
            {
              name = "health"
            },
            {
              name = "ready"
            },
            {
              name       = "forward"
              parameters = ". /etc/resolv.conf"
            },
            {
              name = "reload"
            },
            {
              name = "loadbalance"
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
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "external-dns"
  version    = "0.1.14"
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
      # replicaCount      = 2
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
              zone = "${local.domains.internal}."
            },
          ]
          port = local.ports.gateway_dns
          plugins = [
            {
              name = "errors"
            },
            {
              name       = "health"
              parameters = "127.0.0.1:8080"
            },
            {
              name       = "ready"
              parameters = "127.0.0.1:8181"
            },
            {
              name        = "etcd"
              parameters  = "${local.domains.internal} in-addr.arpa ip6.arpa"
              configBlock = <<EOF
fallthrough in-addr.arpa ip6.arpa
EOF
            },
            {
              name = "reload"
            },
            {
              name = "loadbalance"
            },
          ]
        },
        {
          zones = [
            {
              zone = "."
            },
          ]
          port = local.ports.gateway_dns
          plugins = [
            {
              name = "errors"
            },
            {
              name       = "health"
              parameters = "127.0.0.1:8080"
            },
            {
              name       = "ready"
              parameters = "127.0.0.1:8181"
            },
            {
              name       = "forward"
              parameters = ". /etc/resolv.conf"
            },
            {
              name = "reload"
            },
            {
              name = "loadbalance"
            },
            {
              name       = "cache"
              parameters = 30
            },
          ]
        }
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
  version          = "4.3.0"
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
          proxy-body-size = "256m"
          ssl-redirect    = "true"
        }
        tolerations = [
          {
            effect   = "NoExecute"
            operator = "Exists"
          },
        ]
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

resource "tls_private_key" "letsencrypt-prod" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "letsencrypt-staging" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "helm_release" "cert_issuer_secrets" {
  name             = "cert-issuer"
  repository       = "https://randomcoww.github.io/terraform-infra/"
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
        }
      ]
    }),
  ]
  depends_on = [
    helm_release.cert_manager,
  ]
}

resource "helm_release" "cert_issuer" {
  name       = "cert-issuer"
  repository = "https://randomcoww.github.io/terraform-infra/"
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
}

# authelia #

resource "helm_release" "authelia_users" {
  name             = "authelia-users"
  repository       = "https://randomcoww.github.io/terraform-infra/"
  chart            = "helm-wrapper"
  namespace        = "authelia"
  create_namespace = true
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
              users = var.authelia_users
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
  version          = "0.8.45"
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
          rules = [
            {
              domain = local.kubernetes_ingress_endpoints.mpd
              networks = [
                local.networks.lan.prefix,
                local.networks.service.prefix,
              ]
              policy = "bypass"
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
              domain = local.kubernetes_ingress_endpoints.webdav
              networks = [
                local.networks.lan.prefix,
                local.networks.service.prefix,
              ]
              policy = "bypass"
            },
            {
              domain = local.kubernetes_ingress_endpoints.webdav
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
}

# local-storage storage class #

resource "helm_release" "local-path-provisioner" {
  name       = "local-path-provisioner"
  namespace  = "kube-system"
  repository = "https://charts.containeroo.ch"
  chart      = "local-path-provisioner"
  version    = "0.0.22"
  wait       = false
  values = [
    yamlencode({
      storageClass = {
        name = "local-path"
      }
      nodePathMap = [
        {
          node  = "DEFAULT_PATH_FOR_NON_LISTED_NODES"
          paths = ["${local.pv_mount_path}/local_path_provisioner"]
        },
      ]
    }),
  ]
}

# openebs #

resource "helm_release" "openebs" {
  name             = "openebs"
  namespace        = "openebs"
  repository       = "https://openebs.github.io/charts"
  chart            = "openebs"
  version          = "3.3.0"
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
        basePath = "${local.pv_mount_path}/openebs/local"
      }
      snapshotOperator = {
        enabled = false
      }
      jiva = {
        enabled            = true
        replicas           = 2
        defaultStoragePath = "${local.pv_mount_path}/openebs"
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

# nvidia device plugin #

# resource "helm_release" "nvidia_device_plugin" {
#   name       = "nvidia-device-plugin"
#   repository = "https://nvidia.github.io/k8s-device-plugin"
#   chart      = "nvidia-device-plugin"
#   namespace  = "kube-system"
#   version    = "0.12.2"
#   values = [
#     yamlencode({
#       tolerations = [
#         {
#           effect   = "NoExecute"
#           operator = "Exists"
#         },
#       ]
#     })
#   ]
# }

# amd device plugin #

resource "helm_release" "amd_gpu" {
  name       = "amd-gpu"
  repository = "https://radeonopencompute.github.io/k8s-device-plugin/"
  chart      = "amd-gpu"
  namespace  = "kube-system"
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
        for _, member in local.members.gateway :
        cidrhost(network.prefix, member.netnum)
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
  repository = "https://randomcoww.github.io/terraform-infra/"
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
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "kea"
  version    = "0.1.14"
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
  sync_data_path      = "/var/tmp/matchbox"
  syncthing_peer_port = 22000
}

resource "helm_release" "matchbox" {
  name       = "matchbox"
  namespace  = "default"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "matchbox"
  version    = "0.2.13"
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
  version          = "5.0.0"
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
          memory = "10Gi"
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
      }
      users = []
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
      tolerations = [
        {
          effect   = "NoExecute"
          operator = "Exists"
        },
      ]
    }),
  ]
}

output "minio_endpoint" {
  value = {
    version = "10"
    aliases = {
      minio = {
        url       = "http://${local.services.minio.ip}:${local.ports.minio}"
        accessKey = nonsensitive(random_password.minio-access-key-id.result)
        secretKey = nonsensitive(random_password.minio-secret-access-key.result)
        api       = "S3v4"
        path      = "auto"
      }
    }
  }
}

# hostapd #

module "hostapd-roaming" {
  source        = "./modules/hostapd_roaming"
  resource_name = "hostapd"
  replica_count = 1
}

resource "helm_release" "hostapd" {
  name       = "hostapd"
  namespace  = "default"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "hostapd"
  version    = "0.1.7"
  wait       = false
  values = [
    yamlencode({
      image = local.container_images.hostapd
      peers = [
        for _, peer in module.hostapd-roaming.peers :
        {
          podName = peer.pod_name
          config = {
            interface        = "wlan0"
            preamble         = 1
            noscan           = 1
            auth_algs        = 1
            hw_mode          = "g"
            channel          = 6
            driver           = "nl80211"
            ieee80211n       = 1
            require_ht       = 1
            wmm_enabled      = 1
            disassoc_low_ack = 1
            wpa              = 2
            wpa_key_mgmt     = "SAE"
            wpa_pairwise     = "CCMP"
            country_code     = "US"
            ieee80211d       = 1
            ieee80211h       = 1
            ieee80211w       = 2
            sae_password     = var.hostapd.passphrase
            ssid             = var.hostapd.ssid
            ht_capab = "[${join("][", [
              "LDPC", "HT40-", "HT40+", "SHORT-GI-40", "TX-STBC", "RX-STBC1", "DSSS_CCK-40",
            ])}]"
            # hw_mode                      = "a"
            # channel                      = 149
            # vht_oper_chwidth             = 1
            # vht_oper_centr_freq_seg0_idx = 155
            # ieee80211ac                  = 1
            # require_vht                  = 1
            # vht_capab = "[${join("][", [
            #   "RXLDPC", "TX-STBC-2BY1", "RX-STBC-1", "MAX-A-MPDU-LEN-EXP3", "RX-ANTENNA-PATTERN", "TX-ANTENNA-PATTERN", "SHORT-GI-80",
            # ])}]"
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
          }
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
                      for _, member in local.members.gateway :
                      member.hostname
                    ]
                  },
                  {
                    key      = "kubernetes.io/hostname"
                    operator = "NotIn"
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
    }),
  ]
}
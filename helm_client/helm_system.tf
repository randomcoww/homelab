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
      apiServerIP      = local.vips.apiserver
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
  version    = "1.19.4"
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
        clusterIP = local.vips.cluster_dns
      }
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "role-gateway"
                    operator = "Exists"
                  },
                ]
              },
            ]
          }
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
              parameters = ". ${local.vips.cluster_external_dns}"
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
  version    = "0.1.12"
  wait       = false
  values = [
    yamlencode({
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
      priorityClassName = "system-cluster-critical"
      Deployment = {
        replicaCount = 2
      }
      dataSources = [
        "service",
        "ingress",
      ]
      service = {
        type      = "ClusterIP"
        clusterIP = local.vips.cluster_external_dns
      }
      hostNetwork = {
        enabled = true
      }
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "role-gateway"
                    operator = "Exists"
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
        initialDelaySeconds = 60
        periodSeconds       = 10
        timeoutSeconds      = 5
        failureThreshold    = 5
        successThreshold    = 1
      }
      # coreDNSReadinessProbe = {
      #   httpGet = {
      #     path   = "/ready"
      #     host   = "127.0.0.1"
      #     port   = 8181
      #     scheme = "HTTP"
      #   }
      #   initialDelaySeconds = 60
      #   periodSeconds       = 10
      #   timeoutSeconds      = 5
      #   failureThreshold    = 5
      #   successThreshold    = 1
      # }
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
        }
      ]
    }),
  ]
}

# metallb #

resource "helm_release" "metlallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  namespace        = "metallb-system"
  create_namespace = true
  values = [
    yamlencode({
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
  version          = "4.2.0"
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
          annotations = {
            "metallb.universe.tf/address-pool" = "public-ips"
          }
          externalIPs = [
            local.vips.external_ingress,
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
  version          = "0.8.38"
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
              domain = local.kubernetes_ingress_endpoints.minio
              policy = "bypass"
              networks = [
                local.networks.lan.prefix,
                local.networks.service.prefix,
                local.networks.kubernetes.prefix,
              ]
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
              policy = "one_factor"
            }
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
      nodePathMap = flatten(concat([
        for _, node in local.hosts :
        try({
          node  = node.hostname
          paths = [node.local_provisioner_path]
        }, [])
        ], [
        {
          node  = "DEFAULT_PATH_FOR_NON_LISTED_NODES"
          paths = ["${local.pv_mount_path}/local_path_provisioner"]
        },
      ]))
    }),
  ]
}

# openebs #

resource "helm_release" "openebs" {
  name             = "openebs"
  namespace        = "openebs"
  repository       = "https://openebs.github.io/charts"
  chart            = "openebs"
  version          = "3.2.0"
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

resource "helm_release" "nvidia_device_plugin" {
  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  namespace  = "kube-system"
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

# amd device plugin #

resource "helm_release" "amd_gpu" {
  name       = "amd-gpu"
  repository = "https://radeonopencompute.github.io/k8s-device-plugin/"
  chart      = "amd-gpu"
  namespace  = "kube-system"
  version    = "0.3.0"
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
    local.vips.cluster_kea_primary, local.vips.cluster_kea_secondary
  ]
  shared_data_path = "/var/lib/kea"
  kea_peer_port    = local.ports.kea_peer
  ipxe_file_url    = "http://${local.vips.matchbox}:${local.ports.matchbox}/boot.ipxe"
  cluster_domain   = local.domains.kubernetes
  networks = [
    for _, network in local.networks :
    {
      prefix = network.prefix
      routers = [
        cidrhost(network.prefix, local.vrrp_netnum),
      ]
      domain_name_servers = [
        for _, member in local.members.gateway :
        cidrhost(network.prefix, member.netnum)
      ]
      tftp_server = cidrhost(network.prefix, local.vrrp_netnum)
      mtu         = network.mtu
      pools = [
        cidrsubnet(network.prefix, 1, 1),
      ]
    } if lookup(network, "enable_dhcp_server", false)
  ]
}

resource "helm_release" "kea" {
  name       = "kea"
  namespace  = "default"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "kea"
  version    = "0.1.8"
  wait       = false
  values = [
    yamlencode({
      images = {
        kea   = local.container_images.kea
        tftpd = local.container_images.tftpd
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
        replicaCount = 2
      }
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "role-gateway"
                    operator = "Exists"
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
        tftpd   = local.ports.pxe_tftp
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
  api_listen_ip = local.vips.matchbox
}

module "matchbox-syncthing" {
  source              = "./modules/syncthing_config"
  replica_count       = 2
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
  version    = "0.2.9"
  wait       = false
  values = [
    yamlencode({
      images = {
        matchbox  = local.container_images.matchbox
        syncthing = local.container_images.syncthing
      }
      syncthingConfig = module.matchbox-syncthing.config
      syncthingSecret = module.matchbox-syncthing.secret
      matchboxSecret  = module.matchbox-certs.secret
      sharedDataPath  = "/var/tmp/matchbox"
      StatefulSet = {
        replicaCount = 2
      }
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "role-gateway"
                    operator = "Exists"
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
        annotations = {
          "metallb.universe.tf/address-pool" = "matchbox"
        }
        type = "LoadBalancer"
        port = local.ports.matchbox_api
        externalIPs = [
          local.vips.matchbox,
        ]
      }
      service = {
        annotations = {
          "metallb.universe.tf/address-pool" = "matchbox"
        }
        type = "LoadBalancer"
        port = local.ports.matchbox
        externalIPs = [
          local.vips.matchbox,
        ]
      }
      tftpdService = {
        annotations = {
          "metallb.universe.tf/address-pool" = "matchbox"
        }
        type = "LoadBalancer"
        port = local.ports.pxe_tftp
        externalIPs = [
          local.vips.matchbox,
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

# data "helm_template" "minio" {
resource "helm_release" "minio" {
  name             = split(".", local.kubernetes_service_endpoints.minio)[0]
  namespace        = split(".", local.kubernetes_service_endpoints.minio)[1]
  repository       = "https://charts.min.io/"
  chart            = "minio"
  version          = "4.0.7"
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
        type = "LoadBalancer"
        port = local.ports.minio
        externalIPs = [
          local.vips.minio,
        ]
      }
      ingress = {
        enabled          = true
        ingressClassName = "nginx"
        path             = "/"
        annotations = {
          "cert-manager.io/cluster-issuer"                    = "letsencrypt-prod"
          "nginx.ingress.kubernetes.io/auth-response-headers" = "Remote-User,Remote-Name,Remote-Groups,Remote-Email"
          "nginx.ingress.kubernetes.io/auth-signin"           = "https://${local.kubernetes_ingress_endpoints.auth}"
          "nginx.ingress.kubernetes.io/auth-snippet"          = <<EOF
proxy_set_header X-Forwarded-Method $request_method;
EOF
          "nginx.ingress.kubernetes.io/auth-url"              = "http://${local.kubernetes_service_endpoints.authelia}/api/verify"
        }
        tls = [
          {
            secretName = "minio-tls"
            hosts = [
              local.kubernetes_ingress_endpoints.minio,
            ]
          },
        ]
        hosts = [
          local.kubernetes_ingress_endpoints.minio,
        ]
      }
      users = []
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "role-disks"
                    operator = "Exists"
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
        url       = "https://${local.kubernetes_ingress_endpoints.minio}"
        accessKey = nonsensitive(random_password.minio-access-key-id.result)
        secretKey = nonsensitive(random_password.minio-secret-access-key.result)
        api       = "S3v4"
        path      = "auto"
      }
    }
  }
}

# hostapd #

resource "helm_release" "hostapd" {
  name       = "hostapd"
  namespace  = "default"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "hostapd"
  version    = "0.1.4"
  wait       = false
  values = [
    yamlencode({
      image = local.container_images.hostapd
      config = {
        interface        = "wlan0"
        preamble         = 1
        hw_mode          = "g"
        channel          = 1
        auth_algs        = 1
        driver           = "nl80211"
        ieee80211n       = 1
        require_ht       = 1
        wmm_enabled      = 1
        disassoc_low_ack = 1
        ht_capab = "[${join("][", [
          "LDPC", "HT40-", "HT40+", "SHORT-GI-40", "TX-STBC", "RX-STBC1", "DSSS_CCK-40",
        ])}]"
        wpa            = 2
        wpa_key_mgmt   = "WPA-PSK"
        wpa_pairwise   = "CCMP"
        ieee80211w     = 2
        wpa_passphrase = var.wifi.passphrase
        ssid           = var.wifi.ssid
      }
      StatefulSet = {
        replicaCount = 2
      }
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "role-gateway"
                    operator = "Exists"
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
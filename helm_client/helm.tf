# basic system #

resource "helm_release" "cluster_services" {
  name       = "cluster-services"
  namespace  = "kube-system"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "cluster-services"
  version    = "0.1.8"
  wait       = false
  values = [
    yamlencode({
      images                    = local.container_images
      pod_network_prefix        = local.networks.kubernetes_pod.prefix
      service_network_dns_ip    = local.networks.kubernetes_service.vips.dns
      apiserver_ip              = local.networks.lan.vips.apiserver
      apiserver_port            = local.ports.apiserver
      external_dns_ip           = local.networks.lan.vips.external_dns
      forwarding_dns_ip         = local.networks.lan.vips.forwarding_dns
      internal_domain           = local.domains.internal
      cluster_domain            = local.domains.kubernetes
      cni_bridge_interface_name = local.kubernetes.cni_bridge_interface_name
      kube_proxy_port           = local.ports.kube_proxy
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
  values = [
    yamlencode({
      controller = {
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
            local.networks.service.vips.external_ingress,
          ]
        }
        config = {
          proxy-body-size = "256m"
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
              solvers = [
                {
                  http01 = {
                    ingress = {
                      class = "nginx"
                    }
                  }
                }
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
              solvers = [
                {
                  http01 = {
                    ingress = {
                      class = "nginx"
                    }
                  }
                }
              ]
            }
          }
        },
      ]
    }),
  ]
  depends_on = [
    helm_release.cert_manager,
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
          data = {
            "users_database.yml" = replace(base64encode(chomp(yamlencode({
              users = var.authelia_users
            }))), "\n", "")
          }
        },
      ]
    })
  ]
}

resource "helm_release" "authelia" {
  name             = "authelia"
  repository       = "https://charts.authelia.com"
  chart            = "authelia"
  namespace        = "authelia"
  create_namespace = true
  wait             = false
  values = [
    yamlencode({
      domain = local.domains.internal
      ingress = {
        enabled = true
        annotations = {
          "cert-manager.io/issuer" = "letsencrypt-prod"
        }
        certManager = true
        className   = "nginx"
        subdomain   = "auth"
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
          }
        ]
        extraVolumes = [
          {
            name = "authelia-users"
            secret = {
              secretName = "authelia-users"
            }
          }
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
          default_policy = "one_factor"
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
  values = [
    yamlencode({
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "nvidia.com/gpu"
                    operator = "Exists"
                  },
                ]
              },
            ]
          }
        }
      }
      tolerations = [
        {
          effect   = "NoExecute"
          operator = "Exists"
        },
      ]
    })
  ]
}

# matchbox with data sync #

module "matchbox-certs" {
  source        = "./modules/matchbox_certs"
  api_listen_ip = local.networks.lan.vips.matchbox
}

module "matchbox-syncthing" {
  source              = "./modules/syncthing_config"
  replica_count       = 2
  resource_name       = "matchbox"
  resource_namespace  = "default"
  service_name        = "matchbox"
  sync_data_path      = "/var/tmp/syncthing"
  syncthing_peer_port = local.ports.matchbox_sync
}

resource "helm_release" "matchbox" {
  name       = "matchbox"
  namespace  = "default"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "matchbox"
  version    = "0.1.9"
  wait       = false
  values = [
    yamlencode({
      replicaCount = 2
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
            }
          ]
        }
      }
      matchbox = {
        image    = local.helm_container_images.matchbox
        secret   = module.matchbox-certs.secret
        httpPort = local.ports.matchbox_http
        apiPort  = local.ports.matchbox_api
      }
      syncthing = {
        image    = local.helm_container_images.syncthing
        podName  = "syncthing"
        secret   = module.matchbox-syncthing.secret
        config   = module.matchbox-syncthing.config
        peerPort = local.ports.matchbox_sync
        dataPath = "/var/tmp/syncthing"
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
  name       = "minio"
  namespace  = "default"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "minio"
  wait       = false
  values = [
    yamlencode({
      clusterDomain = local.domains.kubernetes
      image = {
        repository = element(split(":", local.helm_container_images.minio), 0)
        tag        = element(split(":", local.helm_container_images.minio), 1)
      }
      mcImage = {
        repository = element(split(":", local.helm_container_images.mc), 0)
        tag        = element(split(":", local.helm_container_images.mc), 1)
      }
      mode         = "distributed"
      rootUser     = random_password.minio-access-key-id.result
      rootPassword = random_password.minio-secret-access-key.result
      minioAPIPort = local.ports.minio
      persistence = {
        storageClass = "local-path"
      }
      drivesPerNode = 2
      replicas      = 2
      resources = {
        requests = {
          memory = "8Gi"
        }
      }
      users = []
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "minio-data"
                    operator = "Exists"
                  },
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
    }),
  ]
}

output "minio_endpoint" {
  value = {
    version = "10"
    aliases = {
      minio = {
        url       = "http://${local.networks.lan.vips.minio}:${local.ports.minio}"
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
  version    = "0.1.2"
  wait       = false
  values = [
    yamlencode({
      replicaCount = 2
      image        = local.helm_container_images.hostapd
      config       = <<EOF
interface=wlan0
preamble=1
hw_mode=g
channel=4
auth_algs=1
driver=nl80211
ieee80211n=1
require_ht=1
wmm_enabled=1
disassoc_low_ack=1
ht_capab=[LDPC][HT40-][HT40+][SHORT-GI-40][TX-STBC][RX-STBC1][DSSS_CCK-40]
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
ieee80211w=2
wpa_passphrase=${var.wifi.passphrase}
ssid=${var.wifi.ssid}
EOF
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
            }
          ]
        }
      }
    }),
  ]
}

# mpd #

resource "helm_release" "mpd" {
  name       = "mpd"
  namespace  = "default"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "mpd"
  version    = "0.2.15"
  wait       = false
  values = [
    yamlencode({
      mpd = {
        image     = local.helm_container_images.mpd
        cachePath = "/mpd/cache"
      }
      ympd = {
        image = local.helm_container_images.ympd
      }
      rclone = {
        image         = local.helm_container_images.rclone
        minioEndPoint = "http://minio.default:${local.ports.minio}"
        minioBucket   = "music"
      }
      ingress = {
        host           = local.helm_ingress.mpd
        className      = "nginx"
        certSecretName = "mpd-tls"
        annotations = {
          "cert-manager.io/issuer"                            = "letsencrypt-prod"
          "nginx.ingress.kubernetes.io/auth-response-headers" = "Remote-User,Remote-Name,Remote-Groups,Remote-Email"
          "nginx.ingress.kubernetes.io/auth-signin"           = "https://${local.helm_ingress.auth}"
          "nginx.ingress.kubernetes.io/auth-snippet"          = <<EOF
proxy_set_header X-Forwarded-Method $request_method;
EOF
          "nginx.ingress.kubernetes.io/auth-url"              = "http://authelia.authelia.svc.${local.domains.kubernetes}/api/verify"
        }
      }
      storageClass = "openebs-jiva-csi-default"
      config = {
        filesystem_charset = "UTF-8"
        auto_update        = "yes"
      }
      audioOutputs = [
        {
          name = "flac-3"
          port = 8180
          config = {
            tags        = "yes"
            format      = "48000:24:2"
            always_on   = "yes"
            encoder     = "flac"
            compression = 3
            max_clients = 0
          }
        },
        {
          name = "wave"
          port = 8181
          config = {
            tags        = "yes"
            format      = "48000:24:2"
            always_on   = "yes"
            encoder     = "wave"
            max_clients = 0
          }
        },
      ]
    }),
  ]
}
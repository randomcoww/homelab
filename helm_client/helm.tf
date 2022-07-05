# basic system #

resource "helm_release" "cluster_services" {
  name       = "cluster-services"
  namespace  = "kube-system"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "cluster-services"
  version    = "0.1.7"
  wait       = false
  values = [
    yamlencode({
      images                    = local.container_images
      pod_network_prefix        = local.networks.kubernetes_pod.prefix
      service_network_dns_ip    = local.networks.kubernetes_service.vips.dns
      apiserver_ip              = local.networks.lan.vips.apiserver
      apiserver_port            = local.ports.apiserver
      external_dns_ip           = local.networks.metallb.vips.external_dns
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
      configInline = {
        address-pools = [
          {
            name     = "default"
            protocol = "layer2"
            addresses = [
              local.networks.metallb.prefix,
            ]
          },
        ]
      }
    })
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
        service = {
          externalIPs = [
            local.networks.metallb.vips.ingress,
          ]
        }
        config = {
          proxy-body-size = "256m"
        }
      }
    }),
  ]
}

# local-storage storage class #

resource "helm_release" "local-storage-provisioner" {
  name       = "local-storage-provisioner"
  namespace  = "kube-system"
  repository = "https://randomcoww.github.io/sig-storage-local-static-provisioner/"
  chart      = "provisioner"
  version    = "2.6.0-alpha.1"
  wait       = false
  values = [
    yamlencode({
      common = {
        mountDevVolume = false
      }
      classes = [
        {
          name        = "local-storage"
          hostDir     = local.kubernetes.local_storage_class_path
          volumeMode  = "Filesystem"
          namePattern = "*"
          fsType      = "xfs"
          blockCleanerCommand = [
            "/scripts/quick_reset.sh",
          ]
          storageClass = {
            isDefaultClass = true
          }
        },
      ]
      daemonset = {
        tolerations = [
          {
            effect   = "NoSchedule"
            operator = "Exists"
          }
        ]
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
                    key      = "vrrp"
                    operator = "In"
                    values = [
                      "true",
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
                      "matchbox",
                    ]
                  }
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
      mode          = "distributed"
      rootUser      = random_password.minio-access-key-id.result
      rootPassword  = random_password.minio-secret-access-key.result
      minioAPIPort  = local.ports.minio
      persistence = {
        storageClass = "local-storage"
        size         = "300Gi"
      }
      drivesPerNode = 2
      replicas      = 2
      resources = {
        requests = {
          memory = "8Gi"
        }
      }
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "minio-data"
                    operator = "In"
                    values = [
                      "true",
                    ]
                  },
                  {
                    key      = "vrrp"
                    operator = "In"
                    values = [
                      "true",
                    ]
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
                    key      = "wlan"
                    operator = "In"
                    values = [
                      "true",
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
                  }
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

# mpd with cache sync #

module "mpd-syncthing" {
  source             = "./modules/syncthing_config"
  replica_count      = 2
  resource_name      = "mpd"
  resource_namespace = "default"
  service_name       = "mpd"
  sync_data_path     = "/var/tmp/syncthing"
}

resource "helm_release" "mpd" {
  name       = "mpd"
  namespace  = "default"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "mpd"
  version    = "0.1.2"
  wait       = false
  values = [
    yamlencode({
      replicaCount  = 2
      minioEndPoint = "http://minio.default:${local.ports.minio}"
      minioBucket   = "music"
      affinity = {
        podAffinity = {
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
                  }
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            }
          ]
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
                      "mpd",
                    ]
                  }
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            }
          ]
        }
      }
      mpd = {
        image          = local.helm_container_images.mpd
        streamHostName = local.helm_ingress.mpd_stream
      }
      ympd = {
        image        = local.helm_container_images.ympd
        httpHostName = local.helm_ingress.mpd_control
      }
      rclone = {
        image = local.helm_container_images.rclone
      }
      syncthing = {
        image    = local.helm_container_images.syncthing
        podName  = "syncthing"
        secret   = module.mpd-syncthing.secret
        config   = module.mpd-syncthing.config
        dataPath = "/var/tmp/syncthing"
      }
    }),
  ]
}
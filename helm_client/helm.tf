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
          name        = local.kubernetes.local_storage_class
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
    }),
  ]
}

# matchbox with data sync #

module "matchbox-certs" {
  source              = "./modules/matchbox_certs"
  internal_pxeboot_ip = local.networks.metallb.vips.internal_pxeboot
}

module "matchbox-syncthing" {
  source             = "./modules/syncthing_config"
  replica_count      = 2
  resource_name      = "matchbox"
  resource_namespace = "default"
  service_name       = "matchbox"
  sync_data_path     = "/var/tmp/syncthing"
}

resource "helm_release" "matchbox" {
  name       = "matchbox"
  namespace  = "default"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "matchbox"
  version    = "0.1.6"
  wait       = false
  values = [
    yamlencode({
      replicaCount   = 2
      loadBalancerIP = local.networks.metallb.vips.internal_pxeboot
      matchbox = {
        image    = local.container_images.matchbox
        secret   = module.matchbox-certs.secret
        httpPort = local.ports.internal_pxeboot_http
        apiPort  = local.ports.internal_pxeboot_api
      }
      syncthing = {
        image    = local.container_images.syncthing
        podName  = "syncthing"
        secret   = module.matchbox-syncthing.secret
        config   = module.matchbox-syncthing.config
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
  repository = "https://charts.min.io/"
  chart      = "minio"
  wait       = false
  values = [
    yamlencode({
      clusterDomain = local.domains.kubernetes
      mode          = "distributed"
      rootUser      = random_password.minio-access-key-id.result
      rootPassword  = random_password.minio-secret-access-key.result
      persistence = {
        storageClass = local.kubernetes.local_storage_class
        size         = "300Gi"
      }
      drivesPerNode = 2
      replicas      = 2
      ingress = {
        enabled          = true
        ingressClassName = "nginx"
        hosts = [
          local.ingress.minio,
        ]
      }
      consoleIngress = {
        enabled          = true
        ingressClassName = "nginx"
        hosts = [
          local.ingress.minio_console,
        ]
      }
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
        url       = "http://${local.ingress.minio}"
        accessKey = nonsensitive(random_password.minio-access-key-id.result)
        secretKey = nonsensitive(random_password.minio-secret-access-key.result)
        api       = "S3v4"
        path      = "auto"
      }
    }
  }
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
  version    = "0.1.0"
  wait       = false
  values = [
    yamlencode({
      replicaCount  = 2
      minioEndPoint = "http://minio.default:9000"
      minioBucket   = "music"
      mpd = {
        image          = local.container_images.mpd
        streamHostName = local.ingress.mpd_stream
      }
      ympd = {
        image        = local.container_images.ympd
        httpHostName = local.ingress.mpd_control
      }
      rclone = {
        image = local.container_images.rclone
      }
      syncthing = {
        image    = local.container_images.syncthing
        podName  = "syncthing"
        secret   = module.mpd-syncthing.secret
        config   = module.mpd-syncthing.config
        dataPath = "/var/tmp/syncthing"
      }
    }),
  ]
}
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
            reclaimPolicy  = "Delete"
            isDefaultClass = true
          }
        },
      ]
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

# syncthing #

module "syncthing-addon" {
  source             = "./modules/syncthing_config"
  replica_count      = 2
  resource_name      = "syncthing"
  resource_namespace = "default"
  sync_data_path     = "/var/pv/sync"
}

resource "helm_release" "syncthing" {
  name       = "syncthing"
  namespace  = "default"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "syncthing"
  version    = "0.1.1"
  wait       = false
  values = [
    yamlencode({
      replica_count = 2
      data_path     = "/var/pv/sync"
      image         = local.container_images.syncthing
      secret_data   = module.syncthing-addon.secret
      config        = module.syncthing-addon.config
    }),
  ]
}

# matchbox #

module "matchbox-certs" {
  source              = "./modules/matchbox_certs"
  internal_pxeboot_ip = local.networks.metallb.vips.internal_pxeboot
}

resource "helm_release" "matchbox" {
  name       = "matchbox"
  namespace  = "default"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "matchbox"
  version    = "0.1.1"
  wait       = false
  values = [
    yamlencode({
      replica_count              = 2
      data_path                  = "/var/pv/sync/matchbox"
      affinity                   = "syncthing"
      image                      = local.container_images.matchbox
      secret_data                = module.matchbox-certs.secret
      internal_pxeboot_http_port = local.ports.internal_pxeboot_http
      internal_pxeboot_api_port  = local.ports.internal_pxeboot_api
      internal_pxeboot_ip        = local.networks.metallb.vips.internal_pxeboot
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
          memory = "4Gi"
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

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
      images = {
        coredns            = local.container_images.coredns
        etcd               = local.container_images.etcd
        external_dns       = local.container_images.external_dns
        flannel_cni_plugin = local.container_images.flannel_cni_plugin
        flannel            = local.container_images.flannel
        kapprover          = local.container_images.kapprover
        kube_proxy         = local.container_images.kube_proxy
        etcd               = local.container_images.etcd
      }
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
    })
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
              local.networks.metallb.prefix
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
    })
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
    })
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
  name       = "minio"
  namespace  = "default"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "minio"
  version    = "0.1.1"
  wait       = false
  values = [
    yamlencode({
      replica_count      = 1
      image              = local.container_images.minio
      node_affinity      = "aio-0.local"
      minio_ip           = local.networks.metallb.vips.minio
      minio_port         = local.ports.minio
      minio_console_port = local.ports.minio_console
      volume_path        = "/var/pv/minio"
      access_key_id      = replace(base64encode(chomp(random_password.minio-access-key-id.result)), "\n", "")
      secret_access_key  = replace(base64encode(chomp(random_password.minio-secret-access-key.result)), "\n", "")
    })
  ]
}

output "minio_endpoint" {
  value = {
    version = "10"
    aliases = {
      minio = {
        url       = "http://${local.networks.metallb.vips.minio}:${local.ports.minio}"
        accessKey = nonsensitive(random_password.minio-access-key-id.result)
        secretKey = nonsensitive(random_password.minio-secret-access-key.result)
        api       = "S3v4"
        path      = "auto"
      }
    }
  }
}

# mpd #

resource "helm_release" "mpd" {
  name       = "mpd"
  namespace  = "default"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "mpd"
  version    = "0.1.2"
  wait       = false
  values = [
    yamlencode({
      images = {
        rclone = local.container_images.rclone
        mpd    = local.container_images.mpd
        ympd   = local.container_images.ympd
      }
      affinity         = "syncthing"
      minio_endpoint   = "http://minio-0.minio.default.svc:${local.ports.minio}"
      minio_bucket     = "music"
      control_dns_name = "mpd.${local.domains.internal}"
      stream_dns_name  = "s.${local.domains.internal}"
    })
  ]
}

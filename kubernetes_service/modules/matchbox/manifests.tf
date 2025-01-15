locals {
  name      = split(".", var.cluster_service_endpoint)[0]
  namespace = split(".", var.cluster_service_endpoint)[1]
  data_path = "/var/lib/matchbox"
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = local.name
  namespace   = local.namespace
  release     = var.release
  app_version = split(":", var.images.matchbox)[1]
  manifests = merge(module.syncthing.chart.manifests, {
    "templates/service.yaml"     = module.service.manifest
    "templates/service-api.yaml" = module.service-api.manifest
    "templates/secret.yaml"      = module.secret.manifest
  })
}

module "secret" {
  source  = "../../../modules/secret"
  name    = local.name
  app     = local.name
  release = var.release
  data = {
    "ca.crt"     = chomp(var.ca.cert_pem)
    "server.crt" = chomp(tls_locally_signed_cert.matchbox.cert_pem)
    "server.key" = chomp(tls_private_key.matchbox.private_key_pem)
  }
}

module "service" {
  source  = "../../../modules/service"
  name    = local.name
  app     = local.name
  release = var.release
  spec = {
    type              = "LoadBalancer"
    loadBalancerIP    = var.service_ip
    loadBalancerClass = "kube-vip.io/kube-vip-class"
    ports = [
      {
        name       = "matchbox"
        port       = var.ports.matchbox
        protocol   = "TCP"
        targetPort = var.ports.matchbox
      },
    ]
  }
}

module "service-api" {
  source  = "../../../modules/service"
  name    = "${local.name}-api"
  app     = local.name
  release = var.release
  spec = {
    type              = "LoadBalancer"
    loadBalancerIP    = var.api_service_ip
    loadBalancerClass = "kube-vip.io/kube-vip-class"
    ports = [
      {
        name       = "matchbox-api"
        port       = var.ports.matchbox_api
        protocol   = "TCP"
        targetPort = var.ports.matchbox_api
      },
    ]
  }
}

module "syncthing" {
  source = "../statefulset_syncthing"
  ## syncthing config
  sync_data_paths = [
    local.data_path,
  ]
  images = {
    syncthing = var.images.syncthing
  }
  ##
  name     = local.name
  app      = local.name
  release  = var.release
  affinity = var.affinity
  replicas = var.replicas
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    containers = [
      {
        name  = local.name
        image = var.images.matchbox
        args = [
          "-address=0.0.0.0:${var.ports.matchbox}",
          "-rpc-address=0.0.0.0:${var.ports.matchbox_api}",
          "-assets-path=${local.data_path}",
          "-data-path=${local.data_path}",
        ]
        volumeMounts = [
          {
            name      = "matchbox-secret"
            mountPath = "/etc/matchbox"
          },
        ]
        ports = [
          {
            containerPort = var.ports.matchbox
          },
          {
            containerPort = var.ports.matchbox_api
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = var.ports.matchbox
            path   = "/"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = var.ports.matchbox
            path   = "/"
          }
        }
      },
    ]
    volumes = [
      {
        name = "matchbox-secret"
        secret = {
          secretName = module.secret.name
        }
      },
    ]
  }
}
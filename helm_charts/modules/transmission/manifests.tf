locals {
  transmission_home_path = "/var/lib/transmission"
  torrent_done_script    = "/torrent-done.sh"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.transmission)[1]
  manifests = {
    "templates/service.yaml"     = module.service.manifest
    "templates/ingress.yaml"     = module.ingress.manifest
    "templates/secret.yaml"      = module.secret.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    "wg0.conf"        = var.wireguard_config
    "torrent-done.sh" = var.torrent_done_script
    "settings.json" = jsonencode(merge(var.transmission_settings, {
      bind-address-ipv4            = "0.0.0.0"
      script-torrent-done-filename = local.torrent_done_script
      download-dir                 = "${local.transmission_home_path}/downloads"
      incomplete-dir               = "${local.transmission_home_path}/incomplete"
      rpc-port                     = var.ports.transmission
    }))
  }
}

module "service" {
  source  = "../service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "transmission"
        port       = var.ports.transmission
        protocol   = "TCP"
        targetPort = var.ports.transmission
      },
    ]
  }
}

module "ingress" {
  source             = "../ingress"
  name               = var.name
  app                = var.name
  release            = var.release
  ingress_class_name = var.ingress_class_name
  cert_issuer        = var.ingress_cert_issuer
  auth_url           = var.ingress_auth_url
  auth_signin        = var.ingress_auth_signin
  rules = [
    {
      host = var.service_hostname
      paths = [
        {
          service = var.name
          port    = var.ports.transmission
          path    = "/"
        }
      ]
    },
  ]
}

module "statefulset" {
  source   = "../statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  replicas = 1
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    dnsPolicy = "ClusterFirstWithHostNet"
    initContainers = [
      {
        name  = "${var.name}-init"
        image = var.images.transmission
        command = [
          "cp",
          "/tmp/settings.json",
          "${local.transmission_home_path}/",
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = "/tmp/settings.json"
            subPath   = "settings.json"
          },
          {
            name      = "transmission-home"
            mountPath = local.transmission_home_path
          },
        ]
      },
      {
        name  = "${var.name}-wg"
        image = var.images.wireguard
        args = [
          "up",
          "wg0",
        ]
        securityContext = {
          privileged = true
        }
        volumeMounts = [
          {
            name      = "config"
            mountPath = "/etc/wireguard/wg0.conf"
            subPath   = "wg0.conf"
          },
        ]
      },
    ]
    containers = [
      {
        name  = var.name
        image = var.images.transmission
        args = [
          "--config-dir",
          local.transmission_home_path,
        ]
        volumeMounts = [
          {
            name      = "transmission-home"
            mountPath = local.transmission_home_path
          },
          {
            name      = "config"
            mountPath = local.torrent_done_script
            subPath   = "torrent-done.sh"
          },
        ]
        ports = [
          {
            containerPort = var.ports.transmission
          },
        ]
      },
    ]
    volumes = [
      {
        name = "config"
        secret = {
          secretName  = var.name
          defaultMode = 493
        }
      },
    ]
  }
  volume_claim_templates = [
    {
      metadata = {
        name = "transmission-home"
      }
      spec = {
        accessModes = var.storage_access_modes
        resources = {
          requests = {
            storage = var.volume_claim_size
          }
        }
        storageClassName = var.storage_class
      }
    },
  ]
}
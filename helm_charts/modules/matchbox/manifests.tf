locals {
  syncthing_home_path = "/var/lib/syncthing"
  shared_data_path    = "/var/tmp/matchbox"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.matchbox)[1]
  manifests = {
    "templates/service.yaml"          = module.service.manifest
    "templates/service-peer.yaml"     = module.service-peer.manifest
    "templates/secret-matchbox.yaml"  = module.secret-matchbox.manifest
    "templates/secret-syncthing.yaml" = module.secret-syncthing.manifest
    "templates/statefulset.yaml"      = module.statefulset.manifest
  }
}

module "syncthing-config" {
  source              = "../syncthing_config"
  name                = var.name
  app                 = var.name
  namespace           = var.namespace
  replicas            = var.replicas
  syncthing_home_path = local.syncthing_home_path
  sync_data_paths     = [local.shared_data_path]
  ports = {
    syncthing_peer = var.ports.syncthing_peer
  }
}

module "secret-matchbox" {
  source  = "../secret"
  name    = "${var.name}-matchbox"
  app     = var.name
  release = var.release
  data = {
    "ca.crt"     = chomp(var.ca.cert_pem)
    "server.crt" = chomp(tls_locally_signed_cert.matchbox.cert_pem)
    "server.key" = chomp(tls_private_key.matchbox.private_key_pem)
  }
}

module "secret-syncthing" {
  source  = "../secret"
  name    = "${var.name}-syncthing"
  app     = var.name
  release = var.release
  data = merge({
    "config.xml" = module.syncthing-config.config
    }, {
    for peer in module.syncthing-config.peers :
    "cert-${peer.pod_name}" => peer.cert
    }, {
    for peer in module.syncthing-config.peers :
    "key-${peer.pod_name}" => peer.key
  })
}

module "service" {
  source  = "../service"
  name    = var.name
  app     = var.name
  release = var.release
  annotations = {
    "external-dns.alpha.kubernetes.io/hostname" = var.service_hostname
  }
  spec = {
    type = "LoadBalancer"
    externalIPs = [
      var.service_ip,
    ]
    ports = [
      {
        name       = "matchbox"
        port       = var.ports.matchbox
        protocol   = "TCP"
        targetPort = var.ports.matchbox
      },
      {
        name       = "matchbox-api"
        port       = var.ports.matchbox_api
        protocol   = "TCP"
        targetPort = var.ports.matchbox_api
      },
    ]
  }
}

module "service-peer" {
  source  = "../service"
  name    = "${var.name}-peer"
  app     = var.name
  release = var.release
  spec = {
    type      = "ClusterIP"
    clusterIP = "None"
  }
}

module "statefulset" {
  source            = "../statefulset"
  name              = var.name
  app               = var.name
  release           = var.release
  replicas          = var.replicas
  min_ready_seconds = 30
  annotations = {
    "checksum/secret-syncthing" = sha256(module.secret-syncthing.manifest)
    "checksum/secret-matchbox"  = sha256(module.secret-matchbox.manifest)
  }
  spec = {
    hostNetwork = true
    dnsPolicy   = "ClusterFirstWithHostNet"
    initContainers = [
      {
        name  = "${var.name}-init"
        image = var.images.syncthing
        command = [
          "cp",
          "/tmp/config.xml",
          "/tmp/cert.pem",
          "/tmp/key.pem",
          "${local.syncthing_home_path}/",
        ]
        env = [
          {
            name = "POD_NAME"
            valueFrom = {
              fieldRef = {
                fieldPath = "metadata.name"
              }
            }
          },
        ]
        volumeMounts = [
          {
            name      = "syncthing-secret"
            mountPath = "/tmp/config.xml"
            subPath   = "config.xml"
          },
          {
            name        = "syncthing-secret"
            mountPath   = "/tmp/cert.pem"
            subPathExpr = "cert-$(POD_NAME)"
          },
          {
            name        = "syncthing-secret"
            mountPath   = "/tmp/key.pem"
            subPathExpr = "key-$(POD_NAME)"
          },
          {
            name      = "syncthing-home"
            mountPath = local.syncthing_home_path
          },
        ]
      },
    ]
    containers = [
      {
        name  = var.name
        image = var.images.matchbox
        args = [
          "-address=0.0.0.0:${var.ports.matchbox}",
          "-rpc-address=0.0.0.0:${var.ports.matchbox_api}",
          "-assets-path=${local.shared_data_path}",
          "-data-path=${local.shared_data_path}",
        ]
        volumeMounts = [
          {
            name      = "matchbox-secret"
            mountPath = "/etc/matchbox"
          },
          {
            name      = "shared-data"
            mountPath = local.shared_data_path
          },
        ]
        ports = [
          {
            name          = "matchbox"
            containerPort = var.ports.matchbox
          },
          {
            name          = "matchbox-api"
            containerPort = var.ports.matchbox_api
          },
        ]
        livenessProbe = {
          tcpSocket = {
            port = var.ports.matchbox_api
          }
          initialDelaySeconds = 5
          periodSeconds       = 10
          timeoutSeconds      = 5
        }
      },
      {
        name  = "${var.name}-sync"
        image = var.images.syncthing
        command = [
          "syncthing",
        ]
        args = [
          "--home",
          local.syncthing_home_path,
        ]
        volumeMounts = [
          {
            name      = "syncthing-home"
            mountPath = local.syncthing_home_path
          },
          {
            name      = "shared-data"
            mountPath = local.shared_data_path
          },
        ]
        ports = [
          {
            name          = "syncthing-peer"
            containerPort = var.ports.syncthing_peer
          },
        ]
      },
    ]
    volumes = [
      {
        name = "syncthing-home"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "shared-data"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "matchbox-secret"
        secret = {
          secretName = "${var.name}-matchbox"
        }
      },
      {
        name = "syncthing-secret"
        secret = {
          secretName = "${var.name}-syncthing"
        }
      },
    ]
  }
}
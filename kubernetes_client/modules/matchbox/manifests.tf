locals {
  name      = split(".", var.cluster_service_endpoint)[0]
  namespace = split(".", var.cluster_service_endpoint)[1]

  syncthing_home_path = "/var/lib/syncthing"
  shared_data_path    = "/var/tmp/matchbox"
  ports = merge(var.ports, {
    syncthing_peer = 22000
  })
}

module "metadata" {
  source      = "../metadata"
  name        = local.name
  namespace   = local.namespace
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
  source = "../syncthing_config"
  hostnames = [
    for i in range(var.replicas) :
    "${local.name}-${i}.${var.cluster_service_endpoint}"
  ]
  syncthing_home_path = local.syncthing_home_path
  sync_data_paths = [
    local.shared_data_path,
  ]
  ports = {
    syncthing_peer = local.ports.syncthing_peer
  }
}

module "secret-matchbox" {
  source  = "../secret"
  name    = "${local.name}-matchbox"
  app     = local.name
  release = var.release
  data = {
    "ca.crt"     = chomp(var.ca.cert_pem)
    "server.crt" = chomp(tls_locally_signed_cert.matchbox.cert_pem)
    "server.key" = chomp(tls_private_key.matchbox.private_key_pem)
  }
}

module "secret-syncthing" {
  source  = "../secret"
  name    = "${local.name}-syncthing"
  app     = local.name
  release = var.release
  data = merge({
    "config.xml" = module.syncthing-config.config
    }, {
    for peer in module.syncthing-config.peers :
    "cert-${split(".", peer.hostname)[0]}" => peer.cert
    }, {
    for peer in module.syncthing-config.peers :
    "key-${split(".", peer.hostname)[0]}" => peer.key
  })
}

module "service" {
  source  = "../service"
  name    = local.name
  app     = local.name
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
        port       = local.ports.matchbox
        protocol   = "TCP"
        targetPort = local.ports.matchbox
      },
      {
        name       = "matchbox-api"
        port       = local.ports.matchbox_api
        protocol   = "TCP"
        targetPort = local.ports.matchbox_api
      },
      {
        name       = "syncthing-peer"
        port       = local.ports.syncthing_peer
        protocol   = "TCP"
        targetPort = local.ports.syncthing_peer
      },
    ]
  }
}

module "service-peer" {
  source  = "../service"
  name    = "${local.name}-peer"
  app     = local.name
  release = var.release
  spec = {
    type                     = "ClusterIP"
    clusterIP                = "None"
    publishNotReadyAddresses = true
  }
}

module "statefulset" {
  source            = "../statefulset"
  name              = local.name
  app               = local.name
  release           = var.release
  affinity          = var.affinity
  replicas          = var.replicas
  min_ready_seconds = 30
  annotations = {
    "checksum/secret-syncthing" = sha256(module.secret-syncthing.manifest)
    "checksum/secret-matchbox"  = sha256(module.secret-matchbox.manifest)
  }
  spec = {
    containers = [
      {
        name  = local.name
        image = var.images.matchbox
        args = [
          "-address=0.0.0.0:${local.ports.matchbox}",
          "-rpc-address=0.0.0.0:${local.ports.matchbox_api}",
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
            containerPort = local.ports.matchbox
          },
          {
            containerPort = local.ports.matchbox_api
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.ports.matchbox
            path   = "/"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.ports.matchbox
            path   = "/"
          }
        }
      },
      {
        name  = "${local.name}-syncthing"
        image = var.images.syncthing
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e
          mkdir -p ${local.syncthing_home_path}
          cp \
            /tmp/config.xml \
            /tmp/cert.pem \
            /tmp/key.pem \
            ${local.syncthing_home_path}

          exec syncthing \
            --home ${local.syncthing_home_path}
          EOF
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
            name      = "shared-data"
            mountPath = local.shared_data_path
          },
        ]
        ports = [
          {
            containerPort = local.ports.syncthing_peer
          },
        ]
      },
    ]
    volumes = [
      {
        name = "shared-data"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "matchbox-secret"
        secret = {
          secretName = module.secret-matchbox.name
        }
      },
      {
        name = "syncthing-secret"
        secret = {
          secretName = module.secret-syncthing.name
        }
      },
    ]
  }
}
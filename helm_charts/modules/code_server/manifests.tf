locals {
  syncthing_home_path = "/var/lib/syncthing"
  code_home_path      = "/home/${var.user}"
  sync_pod_name       = "${var.name}-sync"

  syncthing_container = {
    name  = "${var.name}-syncthing"
    image = var.images.syncthing
    command = [
      "sh",
      "-c",
      <<EOF
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
        name      = "secret"
        mountPath = "/tmp/config.xml"
        subPath   = "config.xml"
      },
      {
        name        = "secret"
        mountPath   = "/tmp/cert.pem"
        subPathExpr = "cert-$(POD_NAME)"
      },
      {
        name        = "secret"
        mountPath   = "/tmp/key.pem"
        subPathExpr = "key-$(POD_NAME)"
      },
      {
        name      = "code-home"
        mountPath = local.code_home_path
      },
    ]
    ports = [
      {
        name          = "syncthing-peer"
        containerPort = var.ports.syncthing_peer
      },
    ]
  }
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.code_server)[1]
  manifests = {
    "templates/secret.yaml"           = module.secret.manifest
    "templates/service.yaml"          = module.service.manifest
    "templates/service-peer.yaml"     = module.service-peer.manifest
    "templates/ingress.yaml"          = module.ingress.manifest
    "templates/statefulset.yaml"      = module.statefulset.manifest
    "templates/statefulset-sync.yaml" = module.statefulset-sync.manifest
  }
}

module "syncthing-config" {
  source = "../syncthing_config"
  hostnames = concat([
    "${var.name}-0.${var.name}.${var.namespace}.svc"
    ], [
    for i in range(var.sync_replicas) :
    "${local.sync_pod_name}-${i}.${var.name}.${var.namespace}.svc"
  ])
  syncthing_home_path = local.syncthing_home_path
  sync_data_paths     = [local.code_home_path]
  ports = {
    syncthing_peer = var.ports.syncthing_peer
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    TS_AUTHKEY        = var.tailscale_auth_key
    ACCESS_KEY_ID     = var.ssm_access_key_id
    SECRET_ACCESS_KEY = var.ssm_secret_access_key
    ssh_known_hosts   = join("\n", var.ssh_known_hosts)
    }, {
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
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "code-server"
        port       = var.ports.code_server
        protocol   = "TCP"
        targetPort = var.ports.code_server
      },
    ]
    selector = {
      app                                  = var.name
      "statefulset.kubernetes.io/pod-name" = "${var.name}-0"
    }
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
          port    = var.ports.code_server
          path    = "/"
        }
      ]
    },
  ]
}

module "statefulset-sync" {
  source   = "../statefulset"
  name     = local.sync_pod_name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = var.sync_replicas
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    dnsPolicy = "ClusterFirstWithHostNet"
    containers = [
      local.syncthing_container,
    ]
    volumes = [
      {
        name = "secret"
        secret = {
          secretName = var.name
        }
      },
    ]
  }
  volume_claim_templates = [
    {
      metadata = {
        name = "code-home"
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

module "statefulset" {
  source   = "../statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    dnsPolicy = "ClusterFirstWithHostNet"
    containers = [
      {
        name  = var.name
        image = var.images.code_server
        env = concat([
          {
            name  = "USER"
            value = var.user
          },
          {
            name  = "HOME"
            value = local.code_home_path
          },
          {
            name  = "UID"
            value = tostring(var.uid)
          },
          {
            name  = "CODE_PORT"
            value = tostring(var.ports.code_server)
          },
          ], [
          for k, v in var.code_server_extra_envs :
          {
            name  = tostring(k)
            value = tostring(v)
          }
        ])
        volumeMounts = [
          {
            name      = "code-home"
            mountPath = local.code_home_path
          },
          {
            name        = "secret"
            mountPath   = "/etc/ssh/ssh_known_hosts"
            subPathExpr = "ssh_known_hosts"
            readOnly    = true
          },
        ]
        ports = [
          {
            containerPort = var.ports.code_server
          },
        ]
        securityContext = {
          capabilities = {
            add = [
              "AUDIT_WRITE",
            ]
          }
        }
        resources = var.code_server_resources
      },
      {
        name  = "${var.name}-tailscale"
        image = var.images.tailscale
        securityContext = {
          privileged = true
        }
        env = concat([
          {
            name = "POD_NAME"
            valueFrom = {
              fieldRef = {
                fieldPath = "metadata.name"
              }
            }
          },
          {
            name  = "TS_STATE_DIR"
            value = "/var/lib/tailscale"
          },
          {
            name  = "KUBERNETES_SERVICE_HOST"
            value = ""
          },
          {
            name  = "TS_KUBE_SECRET"
            value = "false"
          },
          {
            name  = "TS_USERSPACE"
            value = "false"
          },
          {
            name  = "TS_TAILSCALED_EXTRA_ARGS"
            value = "--state=arn:aws:ssm:${var.aws_region}::parameter/${var.ssm_tailscale_resource}/$(POD_NAME)"
          },
          {
            name = "TS_AUTH_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.name
                key  = "TS_AUTHKEY"
              }
            }
          },
          {
            name  = "AWS_REGION"
            value = var.aws_region
          },
          {
            name = "AWS_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = var.name
                key  = "ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "AWS_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.name
                key  = "SECRET_ACCESS_KEY"
              }
            }
          },
          ], [
          for k, v in var.tailscale_extra_envs :
          {
            name  = tostring(k)
            value = tostring(v)
          }
        ])
      },
      local.syncthing_container,
    ]
    volumes = [
      {
        name = "secret"
        secret = {
          secretName = var.name
        }
      },
    ]
  }
  volume_claim_templates = [
    {
      metadata = {
        name = "code-home"
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
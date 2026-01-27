module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = {
    "templates/secret.yaml"      = module.secret.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
    "templates/role.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "Role"
      metadata = {
        name = var.name
        labels = {
          app     = var.name
          release = var.release
        }
      }
      rules = [
        {
          apiGroups = [""]
          resources = ["secrets"]
          verbs     = ["create"]
        },
        {
          apiGroups = [""]
          resourceNames = [
            for i, _ in range(var.replicas) :
            "${var.name}-${i}"
          ]
          resources = ["secrets"]
          verbs     = ["get", "update", "patch"]
        },
      ]
    })
    "templates/rolebinding.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "RoleBinding"
      metadata = {
        name = var.name
        labels = {
          app     = var.name
          release = var.release
        }
      }
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "Role"
        name     = var.name
      }
      subjects = [
        {
          kind = "ServiceAccount"
          name = var.name
        },
      ]
    })
    "templates/serviceaccount.yaml" = yamlencode({
      apiVersion = "v1"
      kind       = "ServiceAccount"
      metadata = {
        name = var.name
        labels = {
          app     = var.name
          release = var.release
        }
      }
    })
  }
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    TS_AUTHKEY = var.tailscale_auth_key
  }
}

module "statefulset" {
  source   = "../../../modules/statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = var.replicas
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    serviceAccountName = var.name
    priorityClassName  = "system-cluster-critical"
    resources = {
      requests = {
        memory = "128Mi"
      }
      limits = {
        memory = "128Mi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.tailscale
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          ln -sf $(which xtables-nft-multi) $(which iptables)
          ln -sf $(which xtables-nft-multi) $(which ip6tables)
          exec containerboot
          EOF
        ]
        env = concat([
          {
            name = "TS_KUBE_SECRET"
            valueFrom = {
              fieldRef = {
                fieldPath = "metadata.name"
              }
            }
          },
          {
            name  = "TS_USERSPACE"
            value = "false"
          },
          {
            name = "TS_AUTH_KEY"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "TS_AUTHKEY"
              }
            }
          },
          ], [
          for _, e in var.extra_envs :
          {
            name  = e.name
            value = tostring(e.value)
          }
        ])
        volumeMounts = [
          {
            name      = "dev-net-tun"
            mountPath = "/dev/net/tun"
          },
        ]
        securityContext = {
          capabilities = {
            add = [
              "NET_ADMIN",
            ]
          }
        }
        # TODO: add health checks
      },
    ]
    volumes = [
      {
        name = "dev-net-tun"
        hostPath = {
          path = "/dev/net/tun"
        }
      },
    ]
  }
}
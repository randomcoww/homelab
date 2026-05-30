locals {
  metrics_port = 9002

  manifests = concat([
    module.secret.manifest,
    module.statefulset.manifest,
    ], [
    for _, m in [
      {
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
      },
      {
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
      },
      {
        apiVersion = "v1"
        kind       = "ServiceAccount"
        metadata = {
          name = var.name
          labels = {
            app     = var.name
            release = var.release
          }
        }
      },
    ] :
    yamlencode(m)
  ])
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
          {
            name  = "TS_ENABLE_HEALTH_CHECK"
            value = "true"
          },
          {
            name  = "TS_LOCAL_ADDR_PORT"
            value = "0.0.0.0:${local.metrics_port}"
          },
          ], [
          for _, e in var.extra_envs :
          {
            name  = e.name
            value = tostring(e.value)
          }
        ])
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.metrics_port
            path   = "/healthz"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.metrics_port
            path   = "/healthz"
          }
        }
        volumeMounts = [
          {
            name      = "dev-net-tun"
            mountPath = "/dev/net/tun"
          },
          {
            name      = "service-account"
            mountPath = "/var/run/secrets/kubernetes.io/serviceaccount"
            readOnly  = true
          },
        ]
        securityContext = {
          capabilities = {
            add = [
              "NET_ADMIN",
            ]
          }
        }
      },
    ]
    volumes = [
      {
        name = "dev-net-tun"
        hostPath = {
          path = "/dev/net/tun"
        }
      },
      {
        name = "service-account"
        projected = {
          sources = [
            {
              serviceAccountToken = {
                path              = "token"
                expirationSeconds = 3600
              }
            },
            {
              downwardAPI = {
                items = [
                  {
                    path = "namespace"
                    fieldRef = {
                      fieldPath = "metadata.namespace"
                    }
                  },
                ]
              }
            },
            {
              configMap = {
                name = "kube-root-ca.crt"
                items = [
                  {
                    key  = "ca.crt"
                    path = "ca.crt"
                  },
                ]
              }
            },
          ]
        }
      },
    ]
  }
}
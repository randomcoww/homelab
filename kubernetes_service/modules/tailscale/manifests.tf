module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.tailscale)[1]
  manifests = {
    "templates/secret.yaml"      = module.secret.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
    "templates/role.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "Role"
      metadata = {
        name = var.name
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
    containers = [
      {
        name  = var.name
        image = var.images.tailscale
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
        resources       = var.resources
        securityContext = var.security_context
      },
    ]
  }
}
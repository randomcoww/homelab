module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.tailscale)[1]
  manifests = {
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
    TS_AUTHKEY        = var.tailscale_auth_key
    ACCESS_KEY_ID     = var.ssm_access_key_id
    SECRET_ACCESS_KEY = var.ssm_secret_access_key
  }
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
    containers = [
      {
        name  = var.name
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
    ]
  }
}
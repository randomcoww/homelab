locals {
  static_pod = {
    for key, f in {
      tailscale = {
        contents = module.tailscale.manifest
      }
    } :
    key => merge(f, {
      path = "/etc/containers/systemd/${key}.yaml"
    })
  }

  ignition_snippets = concat([
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version     = var.ignition_version
      tailscale_state_path = var.tailscale_state_path
    })
    ], [
    yamlencode({
      variant = "fcos"
      version = var.ignition_version
      storage = {
        files = [
          for _, f in concat(
            values(local.static_pod),
          ) :
          merge({
            mode = 384
            }, f, {
            contents = {
              inline = f.contents
            }
          })
        ]
      }
    })
  ])
}

module "tailscale" {
  source = "../../../modules/static_pod"

  name      = "tailscale"
  namespace = "default"
  spec = {
    containers = [
      {
        name  = "tailscale"
        image = var.images.tailscale
        securityContext = {
          privileged = true
        }
        env = [
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
            value = var.tailscale_state_path
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
            name  = "TS_AUTH_KEY"
            value = var.tailscale_auth_key
          },
        ]
        volumeMounts = [
          {
            name      = "state"
            mountPath = var.tailscale_state_path
          },
        ]
      },
    ]
    volumes = [
      {
        name = "state"
        hostPath = {
          path = var.tailscale_state_path
        }
      },
    ]
  }
}
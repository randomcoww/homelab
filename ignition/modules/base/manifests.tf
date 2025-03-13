locals {
  quadlet_path = "/etc/containers/systemd"
  static_pod = {
    for key, f in {
      terraform-runtime-config = {
        contents = module.terraform-runtime-config.manifest
      }
      terraform-credentials = {
        contents = module.terraform-credentials.manifest
      }
    } :
    key => merge(f, {
      path = "${local.quadlet_path}/${key}.yaml"
    })
  }

  ignition_snippets = concat([
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      butane_version = var.butane_version
      hostname       = var.hostname
      quadlet_path   = local.quadlet_path
    })
    ], [
    yamlencode({
      variant = "fcos"
      version = var.butane_version
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
      passwd = {
        users = [
          {
            name         = "core"
            should_exist = false
          },
        ]
      }
    })
  ])
}

# TODO: Handle credentials for terraform state
module "terraform-credentials" {
  source  = "../../../modules/configmap"
  name    = "terraform-credentials"
  app     = "terraform-runtime-config"
  release = ""
  data = {
    AWS_ENDPOINT_URL_S3   = "https://${var.terraform_backend_bucket.url}"
    AWS_ACCESS_KEY_ID     = var.terraform_backend_bucket.access_key_id
    AWS_SECRET_ACCESS_KEY = var.terraform_backend_bucket.secret_access_key
  }
}

module "terraform-runtime-config" {
  source = "../../../modules/static_pod"

  name      = "terraform-runtime-config"
  namespace = "default"
  spec = {
    restartPolicy = "OnFailure"
    containers = [
      {
        name  = "terraform"
        image = var.images.terraform
        command = [
          "sh",
          "-c",
          <<-EOF
          set -xe

          git clone --depth=1 ${var.terraform_git_repo} /root/tf
          cd /root/tf
          terraform -chdir=runtime_config init
          terraform \
            -chdir=runtime_config apply \
            -auto-approve -var 'hostname=${var.hostname}'
          EOF
        ]
        envFrom = [
          {
            configMapRef = {
              name = "terraform-credentials"
            }
          },
        ]
        volumeMounts = [
          {
            name      = "var"
            mountPath = "/var"
          },
          {
            name      = "etc"
            mountPath = "/etc"
          },
          {
            name      = "home"
            mountPath = "/root"
          },
        ]
      },
    ]
    volumes = [
      {
        name = "var"
        hostPath = {
          path = "/var"
        }
      },
      {
        name = "etc"
        hostPath = {
          path = "/etc"
        }
      },
      {
        name     = "home"
        emptyDir = {}
      },
    ]
  }
}
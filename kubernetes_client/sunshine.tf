module "sunshine" {
  source  = "./modules/sunshine"
  name    = "sunshine"
  release = "0.1.1"
  images = {
    sunshine   = local.container_images.sunshine
    mountpoint = local.container_images.mountpoint
  }
  sunshine_extra_envs = [
    {
      name  = "XDG_RUNTIME_DIR"
      value = "/run/user/${local.users.client.uid}"
    },
  ]
  sunshine_extra_volumes = [
    {
      name = "run-user"
      hostPath = {
        path = "/run/user/${local.users.client.uid}"
        type = "Directory"
      }
    },
  ]
  sunshine_extra_args = [
    {
      name  = "encoder"
      value = "nvenc"
    },
    {
      name  = "key_rightalt_to_key_win"
      value = "enabled"
    },
    {
      name  = "output_name"
      value = "1"
    },
  ]
  sunshine_resources = {
    # limits = {
    #   "nvidia.com/gpu.shared" = 1
    # }
  }
  sunshine_extra_volume_mounts = [
    {
      name      = "run-user"
      mountPath = "/run/user/${local.users.client.uid}"
    },
  ]
  sunshine_security_context = {
    privileged = true
    runAsUser  = local.users.client.uid
    fsGroup    = local.users.client.uid
  }
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "kubernetes.io/hostname"
                operator = "In"
                values = [
                  "de-1.local",
                ]
              },
            ]
          },
        ]
      }
    }
  }
  service_hostname          = local.kubernetes_ingress_endpoints.sunshine
  service_ip                = local.services.sunshine.ip
  admin_hostname            = local.kubernetes_ingress_endpoints.sunshine_admin
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations

  s3_mount_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  s3_mount_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  s3_mount_endpoint          = "http://${local.services.minio.ip}:${local.service_ports.minio}"
  s3_mount_bucket            = local.minio_buckets.fs.name
  s3_mount_extra_args = [
    "--uid ${local.users.client.uid}",
  ]
}
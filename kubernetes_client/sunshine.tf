module "sunshine" {
  source  = "./modules/sunshine"
  name    = "sunshine"
  release = "0.1.1"
  images = {
    sunshine   = local.container_images.sunshine
    jfs        = local.container_images.jfs
    litestream = local.container_images.litestream
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
    limits = {
      "nvidia.com/gpu.shared" = 1
    }
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

  jfs_minio_access_key_id            = data.terraform_remote_state.sr.outputs.minio.access_key_id
  jfs_minio_secret_access_key        = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  jfs_minio_bucket_endpoint          = "http://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}/${local.minio_buckets.jfs.name}"
  litestream_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  litestream_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  litestream_minio_bucket_endpoint   = "http://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}/${local.minio_buckets.litestream.name}"
}
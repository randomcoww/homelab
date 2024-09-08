module "sunshine" {
  source  = "./modules/sunshine"
  name    = "sunshine"
  release = "0.1.1"
  images = {
    sunshine = local.container_images.sunshine
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
}
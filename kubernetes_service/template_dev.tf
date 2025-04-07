## code-server

locals {
  code_mc_config_dir = "/var/tmp/minio"
}

resource "minio_iam_user" "code" {
  name          = "code"
  force_destroy = true
}

resource "minio_iam_policy" "code" {
  name = "code"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.data["models"].arn,
          "${minio_s3_bucket.data["models"].arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "code" {
  user_name   = minio_iam_user.code.id
  policy_name = minio_iam_policy.code.id
}

module "code" {
  source  = "./modules/code_server"
  name    = "code"
  release = "0.1.1"
  images = {
    code_server = local.container_images.code_server
  }
  ports = {
    code_server = local.host_ports.code
  }
  user      = local.users.client.name
  uid       = local.users.client.uid
  home_path = local.users.client.home_dir
  extra_configs = [
    {
      path    = "/etc/ssh/ssh_known_hosts"
      content = "@cert-authority * ${chomp(data.terraform_remote_state.sr.outputs.ssh.ca.public_key_openssh)}"
    },
    {
      path    = "/etc/tmux.conf"
      content = <<-EOF
      set -g history-limit 10000
      set -g mouse on
      set-option -s set-clipboard off
      bind-key -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -in -sel clip"
      EOF
    },
    {
      path    = "${local.code_mc_config_dir}/certs/CAs/ca.crt"
      content = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
    },
    {
      path = "${local.code_mc_config_dir}/config.json"
      content = jsonencode({
        aliases = {
          code = {
            url       = "https://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
            accessKey = minio_iam_user.code.id
            secretKey = minio_iam_user.code.secret
            api       = "S3v4"
            path      = "auto"
          }
        }
      })
    },
  ]
  extra_envs = [
    {
      name  = "MC_CONFIG_DIR"
      value = local.code_mc_config_dir
    },
    {
      name  = "TZ"
      value = local.timezone
    },
  ]
  extra_volume_mounts = [
    {
      name      = "run-podman"
      mountPath = "/run/podman"
    },
    {
      name      = "run-user"
      mountPath = "/run/user/${local.users.client.uid}"
    },
    {
      name      = "mc-config-dir"
      mountPath = local.code_mc_config_dir
    },
  ]
  extra_volumes = [
    {
      name = "run-podman"
      hostPath = {
        path = "/run/podman"
        type = "Directory"
      }
    },
    {
      name = "run-user"
      hostPath = {
        path = "/run/user/${local.users.client.uid}"
        type = "Directory"
      }
    },
    {
      name = "mc-config-dir"
      emptyDir = {
        medium = "Memory"
      }
    },
  ]
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
  service_hostname          = local.kubernetes_ingress_endpoints.code
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
}

## llama-cpp

resource "minio_iam_user" "llama-cpp" {
  name          = "llama-cpp"
  force_destroy = true
}

resource "minio_iam_policy" "llama-cpp" {
  name = "llama-cpp"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.data["models"].arn,
          "${minio_s3_bucket.data["models"].arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "llama-cpp" {
  user_name   = minio_iam_user.llama-cpp.id
  policy_name = minio_iam_policy.llama-cpp.id
}

module "llama-cpp" {
  source    = "./modules/llama_cpp"
  name      = local.kubernetes_services.llama_cpp.name
  namespace = local.kubernetes_services.llama_cpp.namespace
  release   = "0.1.1"
  images = {
    mountpoint = local.container_images.mountpoint
    llama_cpp  = local.container_images.llama_cpp
  }
  ports = {
    llama_cpp = local.service_ports.llama_cpp
  }
  extra_envs = [
    {
      name  = "NVIDIA_VISIBLE_DEVICES"
      value = "all"
    },
    {
      name  = "NVIDIA_DRIVER_CAPABILITIES"
      value = "compute,utility"
    },
    {
      name  = "LLAMA_ARG_MODEL"
      value = "$(MODEL_PATH)/DeepSeek-R1-Distill-Qwen-32B-Q4_K_M-GGUF/deepseek-r1-distill-qwen-32b-q4_k_m.gguf"
    },
    {
      name  = "LLAMA_ARG_ALIAS"
      value = "DeepSeek-R1-Distill-Qwen-32B-Q4_K_M-GGUF"
    },
    {
      name  = "LLAMA_ARG_N_GPU_LAYERS"
      value = "65"
    },
  ]
  service_hostname          = local.kubernetes_ingress_endpoints.llama_cpp
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations
  resources = {
    limits = {
      "nvidia.com/gpu" = 1
    }
  }
  s3_endpoint          = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  s3_bucket            = minio_s3_bucket.data["models"].id
  s3_access_key_id     = minio_iam_user.llama-cpp.id
  s3_secret_access_key = minio_iam_user.llama-cpp.secret
  s3_mount_extra_args = [
    "--cache /tmp",
    "--read-only",
  ]
}

## clickhouse

resource "minio_s3_bucket" "alpaca-db" {
  bucket        = "alpaca-db"
  force_destroy = true
}

resource "minio_iam_user" "alpaca-db" {
  name          = "alpaca-db"
  force_destroy = true
}

resource "minio_iam_policy" "alpaca-db" {
  name = "alpaca-db"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.alpaca-db.arn,
          "${minio_s3_bucket.alpaca-db.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "alpaca-db" {
  user_name   = minio_iam_user.alpaca-db.id
  policy_name = minio_iam_policy.alpaca-db.id
}

module "alpaca-db" {
  source    = "./modules/clickhouse"
  name      = local.kubernetes_services.alpaca_db.name
  namespace = local.kubernetes_services.alpaca_db.namespace
  release   = "0.1.1"
  replicas  = 3
  images = {
    clickhouse = local.container_images.clickhouse
    s3fs       = local.container_images.s3fs
  }
  ports = {
    clickhouse = local.service_ports.clickhouse
    metrics    = local.service_ports.metrics
  }
  # Use same CA as minio backend
  ca = data.terraform_remote_state.sr.outputs.trust.ca
  # extra_users_config = {
  #   users = {
  #     default = {
  #       "@replace" = "replace"
  #       ssl_certificates = {
  #         common_name = [
  #           "${local.kubernetes_services.alpaca_db.endpoint}:default",
  #           "${local.kubernetes_ingress_endpoints.alpaca_db}:default",
  #         ]
  #       }
  #       networks = {
  #         ip = [
  #           "::/0",
  #         ]
  #       }
  #       profile                  = "default"
  #       quota                    = "default"
  #       access_management        = 1
  #       named_collection_control = 1
  #     }
  #   }
  # }
  service_hostname        = local.kubernetes_ingress_endpoints.alpaca_db
  loadbalancer_class_name = "kube-vip.io/kube-vip-class"

  s3_endpoint          = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  s3_bucket            = minio_s3_bucket.alpaca-db.id
  s3_access_key_id     = minio_iam_user.alpaca-db.id
  s3_secret_access_key = minio_iam_user.alpaca-db.secret
  s3_mount_extra_args = [
    "compat_dir",
    "use_path_request_style",
    "allow_other",
  ]
}
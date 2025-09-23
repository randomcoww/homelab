## internal registry

resource "random_password" "event-listener-token" {
  length  = 60
  special = false
}

resource "minio_s3_bucket" "registry" {
  bucket        = "registry"
  force_destroy = true
}

resource "minio_iam_user" "registry" {
  name          = "registry"
  force_destroy = true
}

resource "minio_iam_policy" "registry" {
  name = "registry"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*",
        ]
        Resource = [
          minio_s3_bucket.registry.arn,
          "${minio_s3_bucket.registry.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "registry" {
  user_name   = minio_iam_user.registry.id
  policy_name = minio_iam_policy.registry.id
}

module "registry" {
  source    = "./modules/registry"
  name      = local.kubernetes_services.registry.name
  namespace = local.kubernetes_services.registry.namespace
  release   = "0.1.1"
  replicas  = 2
  images = {
    registry = local.container_images.registry
  }
  ports = {
    registry = local.service_ports.registry
  }
  ca                      = data.terraform_remote_state.sr.outputs.trust.ca
  service_ip              = local.services.registry.ip
  loadbalancer_class_name = "kube-vip.io/kube-vip-class"
  event_listener_token    = random_password.event-listener-token.result
  event_listener_url      = "https://${local.ingress_endpoints.registry_ui}/event-receiver"

  s3_endpoint          = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  s3_bucket            = minio_s3_bucket.registry.id
  s3_bucket_prefix     = "/"
  s3_access_key_id     = minio_iam_user.registry.id
  s3_secret_access_key = minio_iam_user.registry.secret

  depends_on = [
    minio_iam_user.registry,
    minio_iam_policy.registry,
    minio_iam_user_policy_attachment.registry,
  ]
}

module "registry-ui" {
  source    = "./modules/registry_ui"
  name      = "registry-ui"
  namespace = "default"
  release   = "0.1.1"
  images = {
    registry_ui = local.container_images.registry_ui
  }
  registry_url              = "${local.kubernetes_services.registry.endpoint}:${local.service_ports.registry}"
  registry_ca_cert          = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
  service_hostname          = local.ingress_endpoints.registry_ui
  timezone                  = local.timezone
  event_listener_token      = random_password.event-listener-token.result
  ingress_class_name        = local.kubernetes.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations
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
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
        ]
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
    llama_cpp  = local.container_images.llama_cpp
    mountpoint = local.container_images.mountpoint
  }
  ports = {
    llama_cpp = local.service_ports.llama_cpp
  }
  service_hostname = local.ingress_endpoints.llama_cpp
  llama_swap_config = {
    healthCheckTimeout = 600
    models = {
      # https://github.com/ggml-org/llama.cpp/discussions/15396
      # https://docs.unsloth.ai/basics/gpt-oss-how-to-run-and-fine-tune#recommended-settings
      "ggml-gpt-oss-20b-mxfp4" = {
        cmd = <<-EOF
        /app/llama-server \
          --port $${PORT} \
          --model /models/gpt-oss-20b-mxfp4.gguf \
          --ctx-size 32768 \
          --ubatch-size 4096 \
          --batch-size 4096 \
          --jinja \
          --temp 1.0 \
          --top_p 1.0 \
          --top_k 0
        EOF
      }
      "jina-embeddings-v4-text-retrieval-q8" = {
        cmd = <<-EOF
        /app/llama-server \
          --port $${PORT} \
          --model /models/jina-embeddings-v4-text-retrieval-Q8_0.gguf \
          --pooling mean \
          --embedding \
          --ubatch-size 8192
        EOF
      }
    }
  }
  extra_envs = [
    {
      name  = "NVIDIA_DRIVER_CAPABILITIES"
      value = "compute,utility"
    },
    {
      name  = "GGML_CUDA_ENABLE_UNIFIED_MEMORY"
      value = 1
    },
  ]
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
    "--read-only",
  ]
  ingress_class_name        = local.kubernetes.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  depends_on = [
    minio_iam_user.llama-cpp,
    minio_iam_policy.llama-cpp,
    minio_iam_user_policy_attachment.llama-cpp,
  ]
}

## SearXNG

module "searxng" {
  source    = "./modules/searxng"
  name      = local.kubernetes_services.searxng.name
  namespace = local.kubernetes_services.searxng.namespace
  release   = "0.1.1"
  replicas  = 2
  images = {
    searxng = local.container_images.searxng
    valkey  = local.container_images.valkey
  }
  ports = {
    searxng = local.service_ports.searxng
  }
  searxng_settings = {
    use_default_settings = {
      engines = {
        keep_only = [
          "google",
          "duckduckgo",
        ]
      }
    }
    general = {
      debug = true
    }
    search = {
      autocomplete = ""
      safe_search  = 0
      default_lang = "auto"
      formats = [
        "json",
      ]
    }
  }
}

## flowise

resource "minio_s3_bucket" "flowise" {
  bucket        = "flowise"
  force_destroy = true
}

resource "minio_iam_user" "flowise" {
  name          = "flowise"
  force_destroy = true
}

resource "minio_iam_policy" "flowise" {
  name = "flowise"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
        ]
        Resource = [
          minio_s3_bucket.flowise.arn,
          "${minio_s3_bucket.flowise.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "flowise" {
  user_name   = minio_iam_user.flowise.id
  policy_name = minio_iam_policy.flowise.id
}

module "flowise" {
  source    = "./modules/flowise"
  name      = "flowise"
  namespace = "default"
  release   = "0.1.1"
  images = {
    flowise    = local.container_images.flowise
    litestream = local.container_images.litestream
  }
  service_hostname = local.ingress_endpoints.flowise
  extra_configs = {
    STORAGE_TYPE                 = "s3"
    S3_STORAGE_BUCKET_NAME       = minio_s3_bucket.flowise.id
    S3_STORAGE_ACCESS_KEY_ID     = minio_iam_user.flowise.id
    S3_STORAGE_SECRET_ACCESS_KEY = minio_iam_user.flowise.secret
    S3_STORAGE_REGION            = "NA"
    S3_ENDPOINT_URL              = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
    S3_FORCE_PATH_STYLE          = true
    SMTP_HOST                    = var.smtp.host
    SMTP_PORT                    = var.smtp.port
    SMTP_USER                    = var.smtp.username
    SMTP_PASSWORD                = var.smtp.password
    SMTP_SECURE                  = true
    SENDER_EMAIL                 = var.smtp.username
  }
  ingress_class_name        = local.kubernetes.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  minio_endpoint          = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket            = minio_s3_bucket.flowise.id
  minio_litestream_prefix = "$POD_NAME/litestream"
  minio_access_key_id     = minio_iam_user.flowise.id
  minio_secret_access_key = minio_iam_user.flowise.secret
  minio_ca_cert           = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem

  depends_on = [
    minio_iam_user.flowise,
    minio_iam_policy.flowise,
    minio_iam_user_policy_attachment.flowise,
  ]
}

## code-server

locals {
  code_mc_config_dir = "/var/tmp/minio"
}

resource "minio_s3_bucket" "code" {
  bucket        = "code"
  force_destroy = true
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
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
        ]
        Resource = [
          minio_s3_bucket.code.arn,
          "${minio_s3_bucket.code.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "code" {
  user_name   = minio_iam_user.code.id
  policy_name = minio_iam_policy.code.id
}

resource "minio_iam_user" "code-client" {
  name          = "code-client"
  force_destroy = true
}

resource "minio_iam_policy" "code-client" {
  name = "code-client"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
        ]
        Resource = [
          minio_s3_bucket.data["models"].arn,
          "${minio_s3_bucket.data["models"].arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "code-client" {
  user_name   = minio_iam_user.code-client.id
  policy_name = minio_iam_policy.code-client.id
}

module "code-server" {
  source  = "./modules/code_server"
  name    = "code-server"
  release = "0.1.1"
  images = {
    code_server = local.container_images.code_server
    jfs         = local.container_images.juicefs
    litestream  = local.container_images.litestream
  }
  user = "code"
  uid  = 10000
  extra_configs = [
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
      path    = "/etc/pki/ca-trust/source/anchors/ca-cert.pem"
      content = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
    },
    {
      path = "${local.code_mc_config_dir}/config.json"
      content = jsonencode({
        aliases = {
          m = {
            url       = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
            accessKey = minio_iam_user.code-client.id
            secretKey = minio_iam_user.code-client.secret
            api       = "S3v4"
            path      = "auto"
          }
        }
      })
    },
  ]
  extra_envs = [
    {
      name  = "TZ"
      value = local.timezone
    },
    {
      name  = "MC_CONFIG_DIR"
      value = local.code_mc_config_dir
    },
    {
      name  = "NVIDIA_DRIVER_CAPABILITIES"
      value = "compute,utility"
    },
  ]
  extra_volume_mounts = [
    {
      name      = "minio-path"
      mountPath = local.code_mc_config_dir
    },
  ]
  extra_volumes = [
    {
      name = "minio-path"
      emptyDir = {
        medium = "Memory"
      }
    },
  ]
  resources = {
    limits = {
      "nvidia.com/gpu" = 1
    }
  }
  service_hostname          = local.ingress_endpoints.code_server
  ingress_class_name        = local.kubernetes.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  minio_endpoint          = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket            = minio_s3_bucket.code.id
  minio_access_key_id     = minio_iam_user.code.id
  minio_secret_access_key = minio_iam_user.code.secret
  minio_ca_cert           = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem

  depends_on = [
    minio_iam_user.code,
    minio_iam_policy.code,
    minio_iam_user_policy_attachment.code,
  ]
}
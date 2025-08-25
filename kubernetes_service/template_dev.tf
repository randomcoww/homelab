## docker distribution registry

resource "minio_s3_bucket" "distribution" {
  bucket        = "distribution"
  force_destroy = true
}

resource "minio_iam_user" "distribution" {
  name          = "distribution"
  force_destroy = true
}

resource "minio_iam_policy" "distribution" {
  name = "distribution"
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
          minio_s3_bucket.distribution.arn,
          "${minio_s3_bucket.distribution.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "distribution" {
  user_name   = minio_iam_user.distribution.id
  policy_name = minio_iam_policy.distribution.id
}

module "distribution" {
  source    = "./modules/distribution"
  name      = local.kubernetes_services.distribution.name
  namespace = local.kubernetes_services.distribution.namespace
  release   = "0.1.1"
  replicas  = 2
  images = {
    distribution = local.container_images.distribution
  }
  ports = {
    distribution = local.service_ports.distribution
  }
  ca                 = data.terraform_remote_state.sr.outputs.trust.ca
  cluster_service_ip = local.services.cluster_distribution.ip

  s3_endpoint          = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  s3_bucket            = minio_s3_bucket.distribution.id
  s3_bucket_prefix     = "/"
  s3_access_key_id     = minio_iam_user.distribution.id
  s3_secret_access_key = minio_iam_user.distribution.secret

  depends_on = [
    minio_iam_user.distribution,
    minio_iam_policy.distribution,
    minio_iam_user_policy_attachment.distribution,
  ]
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
  service_hostname = local.kubernetes_ingress_endpoints.llama_cpp
  llama_swap_config = {
    healthCheckTimeout = 600
    models = {
      # https://github.com/ggml-org/llama.cpp/discussions/15396
      # https://docs.unsloth.ai/basics/gpt-oss-how-to-run-and-fine-tune#recommended-settings
      "gpt-oss-20b" = {
        cmd = <<-EOF
        /app/llama-server \
          --port $${PORT} \
          --model /models/gpt-oss-20b-mxfp4.gguf \
          --ctx-size 131072 \
          --ubatch-size 4096 \
          --batch-size 4096 \
          --flash-attn \
          --jinja \
          --temp 1.0 \
          --top_p 1.0 \
          --top_k 0
        EOF
      }
      "jina-embeddings-v4-text-retrieval" = {
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
      value = "1"
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
    "--cache /tmp",
    "--read-only",
  ]
  ingress_class_name        = local.ingress_classes.ingress_nginx
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
  service_hostname = local.kubernetes_ingress_endpoints.flowise
  trusted_ca       = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
  extra_configs = {
    STORAGE_TYPE                 = "s3"
    S3_STORAGE_BUCKET_NAME       = minio_s3_bucket.flowise.id
    S3_STORAGE_ACCESS_KEY_ID     = minio_iam_user.flowise.id
    S3_STORAGE_SECRET_ACCESS_KEY = minio_iam_user.flowise.secret
    S3_STORAGE_REGION            = "NA"
    S3_ENDPOINT_URL              = "https://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
    S3_FORCE_PATH_STYLE          = true
    SMTP_HOST                    = var.smtp.host
    SMTP_PORT                    = var.smtp.port
    SMTP_USER                    = var.smtp.username
    SMTP_PASSWORD                = var.smtp.password
    SMTP_SECURE                  = true
    SENDER_EMAIL                 = var.smtp.username
  }
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  minio_endpoint          = "https://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
  minio_bucket            = minio_s3_bucket.flowise.id
  minio_litestream_prefix = "$POD_NAME/litestream"
  minio_access_key_id     = minio_iam_user.flowise.id
  minio_secret_access_key = minio_iam_user.flowise.secret

  depends_on = [
    minio_iam_user.flowise,
    minio_iam_policy.flowise,
    minio_iam_user_policy_attachment.flowise,
  ]
}
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
  args = [
    "--flash-attn",
    "--jinja",
    "--temp",
    "1.0",
    "--top_p",
    "1.0",
    "--top_k",
    0,
  ]
  extra_envs = [
    {
      name  = "NVIDIA_DRIVER_CAPABILITIES"
      value = "compute,utility"
    },
    {
      name  = "LLAMA_ARG_MODEL"
      value = "/models/gpt-oss-20b-mxfp4.gguf"
    },
    {
      name  = "LLAMA_ARG_ALIAS"
      value = "gpt-oss-20b"
    },
    {
      name  = "LLAMA_ARG_THINK"
      value = "auto"
    },
    {
      name  = "LLAMA_ARG_N_GPU_LAYERS"
      value = 99
    },
    {
      name  = "LLAMA_ARG_CTX_SIZE"
      value = 16384
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
        Action = "*"
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
}
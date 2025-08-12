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
      name  = "LLAMA_ARG_N_GPU_LAYERS"
      value = 26
    },
    {
      name  = "LLAMA_ARG_CTX_SIZE"
      value = 20480
    },
    {
      name  = "FORMAT"
      value = "none"
    },
    {
      name  = "LLAMA_ARG_THREADS"
      value = 1
    },
  ]
  security_context = {
    # TODO: Revisit. Open /dev/nvidia-uvm currently fails without this.
    privileged = true
  }
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

## Open WebUI

resource "minio_s3_bucket" "open-webui" {
  bucket        = "open-webui"
  force_destroy = true
}

resource "minio_iam_user" "open-webui" {
  name          = "open-webui"
  force_destroy = true
}

resource "minio_iam_policy" "open-webui" {
  name = "open-webui"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.open-webui.arn,
          "${minio_s3_bucket.open-webui.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "open-webui" {
  user_name   = minio_iam_user.open-webui.id
  policy_name = minio_iam_policy.open-webui.id
}

module "open-webui" {
  source    = "./modules/open_webui"
  name      = "open-webui"
  namespace = "default"
  release   = "0.1.1"
  images = {
    open_webui = local.container_images.open_webui
    litestream = local.container_images.litestream
  }
  service_hostname = local.kubernetes_ingress_endpoints.open_webui
  trusted_ca       = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
  extra_configs = {
    WEBUI_URL                   = "https://${local.kubernetes_ingress_endpoints.open_webui}"
    ENABLE_SIGNUP               = false
    ENABLE_LOGIN_FORM           = false
    DEFAULT_MODELS              = "gpt-oss-20b"
    WEBUI_AUTH                  = false
    ENABLE_VERSION_UPDATE_CHECK = false
    ENABLE_OPENAI_API           = true
    OPENAI_API_BASE_URL         = "http://${local.kubernetes_services.llama_cpp.endpoint}:${local.service_ports.llama_cpp}"
    ENABLE_WEB_SEARCH           = true
    WEB_SEARCH_ENGINE           = "duckduckgo"
    WEB_SEARCH_RESULT_COUNT     = 4
    STORAGE_PROVIDER            = "s3"
    S3_ACCESS_KEY_ID            = minio_iam_user.open-webui.id
    S3_SECRET_ACCESS_KEY        = minio_iam_user.open-webui.secret
    S3_ADDRESSING_STYLE         = "path"
    S3_KEY_PREFIX               = "data"
    S3_BUCKET_NAME              = minio_s3_bucket.open-webui.id
    S3_ENDPOINT_URL             = "https://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
    ENABLE_FOLLOW_UP_GENERATION = false
  }
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  minio_endpoint          = "https://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
  minio_bucket            = minio_s3_bucket.open-webui.id
  minio_litestream_prefix = "$POD_NAME/litestream"
  minio_access_key_id     = minio_iam_user.open-webui.id
  minio_secret_access_key = minio_iam_user.open-webui.secret
}
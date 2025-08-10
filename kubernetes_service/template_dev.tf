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
      name  = "NVIDIA_VISIBLE_DEVICES"
      value = "all"
    },
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
      value = 25
    },
    {
      name  = "LLAMA_ARG_CTX_SIZE"
      value = 20480
    },
    {
      name  = "FORMAT"
      value = "none"
    },
  ]
  # TODO: Nvidia GPU access chain not fully working..
  security_context = {
    privileged = true
  }
  service_hostname          = local.kubernetes_ingress_endpoints.llama_cpp
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations
  resources = {
    # limits = {
    #   "nvidia.com/gpu" = 1
    # }
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

resource "minio_s3_bucket" "node-red" {
  bucket        = "node-red"
  force_destroy = true
}

resource "minio_iam_user" "node-red" {
  name          = "node-red"
  force_destroy = true
}

resource "minio_iam_policy" "node-red" {
  name = "node-red"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.node-red.arn,
          "${minio_s3_bucket.node-red.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "node-red" {
  user_name   = minio_iam_user.node-red.id
  policy_name = minio_iam_policy.node-red.id
}

module "node-red" {
  source    = "./modules/node_red"
  name      = "node-red"
  namespace = "default"
  release   = "0.1.0"
  replicas  = 1
  images = {
    node_red = local.container_images.node_red
    s3fs     = local.container_images.s3fs
  }
  service_hostname          = local.kubernetes_ingress_endpoints.node_red
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  s3_endpoint          = "https://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
  s3_bucket            = minio_s3_bucket.node-red.id
  s3_access_key_id     = minio_iam_user.node-red.id
  s3_secret_access_key = minio_iam_user.node-red.secret
  s3_mount_extra_args = [
    "allow_other",
    "compat_dir",
    "use_path_request_style",
    "uid=1000",
    "gid=1000",
  ]
}
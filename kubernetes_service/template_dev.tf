## internal registry

resource "random_password" "registry-event-listener-token" {
  length  = 60
  special = false
}

module "registry" {
  source    = "./modules/registry"
  name      = local.endpoints.registry.name
  namespace = local.endpoints.registry.namespace
  release   = "0.1.0"
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
  event_listener_token    = random_password.registry-event-listener-token.result
  event_listener_url      = "https://${local.endpoints.registry_ui.ingress}/event-receiver"

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "registry"
  minio_bucket_prefix = "/"
  minio_access_secret = local.minio_users.registry.secret
}

module "registry-ui" {
  source    = "./modules/registry_ui"
  name      = local.endpoints.registry_ui.name
  namespace = local.endpoints.registry_ui.namespace
  release   = "0.1.0"
  images = {
    registry_ui = local.container_images.registry_ui
  }
  registry_url              = "${local.endpoints.registry.service}:${local.service_ports.registry}"
  registry_ca_cert          = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
  service_hostname          = local.endpoints.registry_ui.ingress
  timezone                  = local.timezone
  event_listener_token      = random_password.registry-event-listener-token.result
  ingress_class_name        = local.kubernetes.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations
}

## llama-cpp

module "llama-cpp" {
  source    = "./modules/llama_cpp"
  name      = local.endpoints.llama_cpp.name
  namespace = local.endpoints.llama_cpp.namespace
  release   = "0.1.0"
  images = {
    llama_cpp  = local.container_images.llama_cpp
    mountpoint = local.container_images.mountpoint
  }
  service_hostname = local.endpoints.llama_cpp.ingress
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
  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "data-models"
  minio_access_secret = local.minio_users.llama_cpp.secret
  minio_mount_extra_args = [
    "--read-only",
  ]
  ingress_class_name        = local.kubernetes.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations
}

## SearXNG

module "searxng" {
  source    = "./modules/searxng"
  name      = local.endpoints.searxng.name
  namespace = local.endpoints.searxng.namespace
  release   = "0.1.0"
  replicas  = 2
  images = {
    searxng = local.container_images.searxng
    valkey  = local.container_images.valkey
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
  service_hostname          = local.endpoints.searxng.ingress
  ingress_class_name        = local.kubernetes.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations
}

## flowise

module "flowise" {
  source    = "./modules/flowise"
  name      = local.endpoints.flowise.name
  namespace = local.endpoints.flowise.namespace
  release   = "0.1.0"
  images = {
    flowise    = local.container_images.flowise
    litestream = local.container_images.litestream
  }
  service_hostname = local.endpoints.flowise.ingress
  extra_configs = {
    STORAGE_TYPE           = "s3"
    S3_STORAGE_BUCKET_NAME = "flowise"
    S3_STORAGE_REGION      = "NA"
    S3_ENDPOINT_URL        = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
    S3_FORCE_PATH_STYLE    = true
    SMTP_HOST              = var.smtp.host
    SMTP_PORT              = var.smtp.port
    SMTP_USER              = var.smtp.username
    SMTP_PASSWORD          = var.smtp.password
    SMTP_SECURE            = true
    SENDER_EMAIL           = var.smtp.username
  }
  ingress_class_name        = local.kubernetes.ingress_classes.ingress_nginx_external
  nginx_ingress_annotations = local.nginx_ingress_annotations

  minio_endpoint          = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket            = "flowise"
  minio_litestream_prefix = "$POD_NAME/litestream"
  minio_access_secret     = local.minio_users.flowise.secret
}

## code-server

module "code-server" {
  source    = "./modules/code_server"
  name      = local.endpoints.code_server.name
  namespace = local.endpoints.code_server.namespace
  release   = "0.1.0"
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
  ]
  extra_envs = [
    {
      name  = "TZ"
      value = local.timezone
    },
    {
      name  = "NVIDIA_DRIVER_CAPABILITIES"
      value = "compute,utility"
    },
  ]
  resources = {
    limits = {
      "nvidia.com/gpu" = 1
    }
  }
  service_hostname          = local.endpoints.code_server.ingress
  ingress_class_name        = local.kubernetes.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "code-server"
  minio_access_secret = local.minio_users.code_server.secret
}
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
    WEBUI_URL                        = "https://${local.kubernetes_ingress_endpoints.open_webui}"
    ENABLE_SIGNUP                    = false
    ENABLE_LOGIN_FORM                = false
    DEFAULT_MODELS                   = "gpt-oss-20b"
    WEBUI_AUTH                       = false
    ENABLE_VERSION_UPDATE_CHECK      = false
    ENABLE_OPENAI_API                = true
    OPENAI_API_BASE_URL              = "http://${local.kubernetes_services.llama_cpp.endpoint}:${local.service_ports.llama_cpp}"
    ENABLE_WEB_SEARCH                = true
    WEB_SEARCH_ENGINE                = "duckduckgo"
    WEB_SEARCH_RESULT_COUNT          = 4
    STORAGE_PROVIDER                 = "s3"
    S3_ACCESS_KEY_ID                 = minio_iam_user.open-webui.id
    S3_SECRET_ACCESS_KEY             = minio_iam_user.open-webui.secret
    S3_ADDRESSING_STYLE              = "path"
    S3_KEY_PREFIX                    = "data"
    S3_BUCKET_NAME                   = minio_s3_bucket.open-webui.id
    S3_ENDPOINT_URL                  = "https://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
    ENABLE_FOLLOW_UP_GENERATION      = false
    QUERY_GENERATION_PROMPT_TEMPLATE = <<-EOF
    ## You are a Query Generator Agent (QGA) for an AI architecture. Your role is to craft queries (within a JSON object) to yield the most accurate, grounded, expanded, and timely post-training real-time knowledge, data, and context.

    ### Task:
    Analyze the chat history to determine the necessity of generating search queries, in the given language. Then, generate 2-3 tailored and relevant search queries, ordered by relevance, unless it is absolutely certain that no additional information is required. Your goal is to produce queries to yield the most comprehensive, up-to-date, and valuable information, even with minimal uncertainty. If no search is unequivocally needed, return an empty list.

    Think step-by-step:
    1. Understand the user's question and chat history: Identify key concepts, entities, themes, and any ambiguities or knowledge gaps.
    2. Evaluate if external information is needed: Consider if the topic requires current data (today's date: {{CURRENT_DATE}}), facts, opinions, or validation. If uncertain, default to generating queries.
    3. Format queries: Use simple keywords, Boolean operators (AND, OR, NOT, "exact phrases", parentheses for grouping), date filters (after:YYYY-MM-DD, before:{{CURRENT_DATE}}), truncation (* for variations), and synonyms to broaden scope. Keep each query concise (3-4 key terms max). Include related terms or challenges to assumptions for better coverage.
    4. If more depth is needed, ensure the queries build on each other (e.g., one broad, one specific, one validating). Limit to 3 to avoid overload.

    ### Queries Guidelines:
    1. Focus on universal keywords for web searches; avoid jargon.
    2. Use operators like AND/OR/NOT, " ", (), AROUND(n) for proximity, ~ for synonyms.
    3. Incorporate temporal aspects (e.g., after:2024-01-01 before:{{CURRENT_DATE}} for recent info).
    4. Balance factual and analytical queries.
    5. Ensure queries are distinct and relevant.

    Example for a query on climate change:
    { "queries": ["(climate* AROUND(3) change) AND (\"renewable energy\" OR \"clean power\") after:2022-01-01 before:{{CURRENT_DATE}}", "climate change impacts 2025 predictions", "debunk climate change myths"] }

    ### Output Guidelines:
    - Respond **EXCLUSIVELY** with a JSON object. No extra commentary.
    - Format: { "queries": ["query1", "query2", "query3"] } or { "queries": [] } if none needed.
    - Err on generating queries if any chance of usefulness.
    - Be concise and prioritize high-quality queries.

    ### Chat History:
    <chat_history>
    {{MESSAGES:END:6}}
    </chat_history>

    ## Therefore, your queries (ordered by relevance) within the JSON format are:
    EOF
  }
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  minio_endpoint          = "https://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
  minio_bucket            = minio_s3_bucket.open-webui.id
  minio_litestream_prefix = "$POD_NAME/litestream"
  minio_access_key_id     = minio_iam_user.open-webui.id
  minio_secret_access_key = minio_iam_user.open-webui.secret
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
locals {
  minio_replicas = 4

  minio_static_buckets = {
    boot = {
      acl = "public-read"
    }
    ebooks    = {}
    models    = {}
    documents = {}
    pictures  = {}
    music     = {}
  }

  minio_users = {
    for key, params in {

      # GHA runners access to push to boot
      arc = {
        name      = "arc"
        namespace = "arc-runners"
        policies = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:ListBucket",
              "s3:DeleteObject",
              "s3:AbortMultipartUpload",
            ]
            buckets = [
              "boot",
            ]
          },
        ]
      }

      # internal container registry
      registry = {
        name      = local.endpoints.registry.name
        namespace = local.endpoints.registry.namespace
        policies = [
          {
            Effect = "Allow"
            Action = [
              "s3:*",
            ]
            buckets = [
              "registry"
            ]
          },
        ]
      }

      # llama-cpp mount-s3 access to models
      llama_cpp = {
        name      = local.endpoints.llama_cpp.name
        namespace = local.endpoints.llama_cpp.namespace
        policies = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:ListBucket",
              "s3:DeleteObject",
              "s3:AbortMultipartUpload",
            ]
            buckets = [
              "models",
            ]
          },
        ]
      }

      # open-webui + litestream sqlite
      open_webui = {
        name      = local.endpoints.open_webui.name
        namespace = local.endpoints.open_webui.namespace
        policies = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:ListBucket",
              "s3:DeleteObject",
              "s3:AbortMultipartUpload",
            ]
            buckets = [
              "open-webui",
            ]
          },
        ]
      }

      # kavita mount-s3 access for ebooks
      kavita = {
        name      = local.endpoints.kavita.name
        namespace = local.endpoints.kavita.namespace
        policies = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:ListBucket",
              "s3:DeleteObject",
              "s3:AbortMultipartUpload",
            ]
            buckets = [
              "ebooks",
              "kavita",
            ]
          },
        ]
      }

      # lldap litestream
      lldap = {
        name      = local.endpoints.lldap.name
        namespace = local.endpoints.lldap.namespace
        policies = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:ListBucket",
              "s3:DeleteObject",
              "s3:AbortMultipartUpload",
            ]
            buckets = [
              "lldap",
            ]
          },
        ]
      }

      # authelia litestream
      authelia = {
        name      = local.endpoints.authelia.name
        namespace = local.endpoints.authelia.namespace
        policies = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:ListBucket",
              "s3:DeleteObject",
              "s3:AbortMultipartUpload",
            ]
            buckets = [
              "authelia",
            ]
          },
        ]
      }

      # prometheus-mcp litestream
      prometheus_mcp = {
        name      = local.endpoints.prometheus_mcp.name
        namespace = local.endpoints.prometheus_mcp.namespace
        policies = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:ListBucket",
              "s3:DeleteObject",
              "s3:AbortMultipartUpload",
            ]
            buckets = [
              "prometheus-mcp",
            ]
          },
        ]
      }

    } :

    key => merge(params, {
      namespace = lookup(params, "namespace", "default")
      secret    = "${params.name}-minio-user-secret"
    })
  }

  minio_buckets = merge({
    for _, bucket in distinct(concat(compact(flatten([
      for _, policy in concat(flatten([
        for _, params in local.minio_users :
        params.policies
      ])) :
      lookup(policy, "buckets", [])
    ])))) :
    bucket => {
      force_destroy = true
    }
    }, {
    for name, bucket in local.minio_static_buckets :
    name => bucket
  })
}
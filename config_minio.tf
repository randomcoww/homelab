locals {
  minio_replicas = 4

  minio_static_buckets = {
    data-boot = {
      acl = "public-read"
    }
    data-music = {
    }
    data-pictures = {
    }
    data-models = {
    }
    data-videos = {
    }
    registry = {
    }
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
              "data-boot",
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
              "data-models",
            ]
          },
        ]
      }

      # flowise + litestream sqlite
      flowise = {
        name      = local.endpoints.flowise.name
        namespace = local.endpoints.flowise.namespace
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
              "flowise",
            ]
          },
        ]
      }

      # code-server juicefs + litestream sqlite
      code_server = {
        name      = local.endpoints.code_server.name
        namespace = local.endpoints.code_server.namespace
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
              "code-server",
            ]
          },
        ]
      }

      # audioserve mount-s3 access to music
      audioserve = {
        name      = local.endpoints.audioserve.name
        namespace = local.endpoints.audioserve.namespace
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
              "data-music",
            ]
          },
        ]
      }

      # rclone access to pictures for webdav
      webdav_pictures = {
        name      = local.endpoints.webdav_pictures.name
        namespace = local.endpoints.webdav_pictures.namespace
        policies = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:ListBucket",
            ]
            buckets = [
              "data-pictures",
            ]
          },
        ]
      }

      # matchbox mount-s3 access to boot
      matchbox = {
        name      = local.endpoints.matchbox.name
        namespace = local.endpoints.matchbox.namespace
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
              "matchbox",
            ]
          },
        ]
      }

      # vaultwarden litestream sqlite
      vaultwarden = {
        name      = local.endpoints.vaultwarden.name
        namespace = local.endpoints.vaultwarden.namespace
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
              "vaultwarden",
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
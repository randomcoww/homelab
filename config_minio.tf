locals {
  minio_replicas = 4

  minio_static_buckets = {
    boot = {
      acl = "public-read"
    }
    music = {
    }
    pictures = {
    }
    models = {
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
              "music",
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
              "pictures",
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
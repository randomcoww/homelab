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
    data-videos = {
    }
    data-models = {
    }
  }

  minio_users_base = {
    # GHA runners access to push to boot
    arc = {
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
    llama-cpp = {
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
    code = {
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
            "code",
          ]
        },
      ]
    }

    # audioserve mount-s3 access to music
    audioserve = {
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
    rclone-pictures = {
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

    # rclone access to videos for webdav
    rclone-videos = {
      policies = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:ListBucket",
          ]
          buckets = [
            "data-videos",
          ]
        },
      ]
    }

    # matchbox mount-s3 access to boot
    matchbox = {
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
      namespace = "vaultwarden"
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
      acl           = "private"
      force_destroy = true
    }
    }, {
    for name, bucket in local.minio_static_buckets :
    name => merge({
      force_destroy = false
      acl           = "private"
    }, bucket)
  })

  minio_users = {
    for name, params in local.minio_users_base :
    name => merge(params, {
      namespace = lookup(params, "namespace", "default")
      secret    = "${name}-minio-user-secret"
    })
  }
}
locals {
  minio_replicas = 4

  minio_static_buckets = {
    boot = {
      acl = "public-read"
    }
    ebooks = {}
    music  = {}
    fluxcd = {}
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

      # stump juicefs and litestream
      stump = {
        name      = local.endpoints.stump.name
        namespace = local.endpoints.stump.namespace
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
              "stump",
            ]
          },
        ]
      }

      # navidrome litestream
      navidrome = {
        name      = local.endpoints.navidrome.name
        namespace = local.endpoints.navidrome.namespace
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
              "navidrome",
            ]
          },
        ]
      }

      # prometheus thanos sidecar
      prometheus = {
        name      = local.endpoints.prometheus.name
        namespace = local.endpoints.prometheus.namespace
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
              "prometheus",
            ]
          },
        ]
      }

      # fluxcd bucket ops
      fluxcd = {
        name      = "fluxcd"
        namespace = "flux-system"
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
              "fluxcd",
            ]
          },
        ]
      }

      # hermes-agent juicefs
      hermes_agent = {
        name      = local.endpoints.hermes_agent.name
        namespace = local.endpoints.hermes_agent.namespace
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
              "hermes-agent",
            ]
          },
        ]
      }

      # mountpoint-s3-csi
      mountpoint_s3_csi = {
        name      = local.endpoints.mountpoint_s3_csi.name
        namespace = local.endpoints.mountpoint_s3_csi.namespace
        policies = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:ListBucket",
            ]
            buckets = [
              "music",
              "ebooks",
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
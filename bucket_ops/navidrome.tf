resource "minio_s3_bucket" "navidrome" {
  bucket         = "navidrome"
  acl            = "private"
  force_destroy  = true
  object_locking = false
}

resource "minio_iam_user" "navidrome" {
  name          = "navidrome"
  force_destroy = true
}

resource "minio_iam_policy" "navidrome" {
  name = "navidrome"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
        ]
        Resource = [
          minio_s3_bucket.navidrome.arn,
          "${minio_s3_bucket.navidrome.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "navidrome" {
  user_name   = minio_iam_user.navidrome.id
  policy_name = minio_iam_policy.navidrome.id
}

module "navidrome" {
  source    = "./modules/navidrome"
  name      = "navidrome"
  namespace = "default"
  replicas  = 1
  images = {
    navidrome = {
      repository = "ghcr.io/navidrome/navidrome"
      tag        = "0.64.2@sha256:38dc2727bfcfd5ede290f8ada114fc90368146f265ae4701ddddbcbe2a44ee52" # renovate: datasource=docker depName=ghcr.io/navidrome/navidrome
    }
    litestream = {
      repository = "docker.io/litestream/litestream"
      tag        = "0.5.18@sha256:513bff62a88fc0c86c73d27333c41c54c89fe890a7c32a551600adff9309b11b" # renovate: datasource=docker depName=docker.io/litestream/litestream
    }
  }
  extra_envs = {
    ND_EXTAUTH_USERHEADER = "Remote-User"
    ND_EXTAUTH_TRUSTEDSOURCES = join(",", [
      local.networks.kubernetes_pod.prefix,
    ])
    TZ = local.timezone
  }
  ingress_hostname = local.endpoints.navidrome.hostname
  gateway_ref = {
    name      = local.services.cilium.name
    namespace = local.services.cilium.namespace
  }
  external_auth_filter = local.authelia_external_auth_filter
  minio_endpoint       = "https://${local.services.minio.name}.${local.services.minio.namespace}:${local.service_ports.minio}"
  minio_data_bucket    = "music"
  minio_bucket         = "navidrome"
  minio_user           = minio_iam_user.navidrome
}

resource "minio_s3_object" "fluxcd-navidrome" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.navidrome.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "navidrome/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}

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
  name      = local.endpoints.navidrome.name
  namespace = local.endpoints.navidrome.namespace
  images = {
    navidrome = {
      repository = "ghcr.io/navidrome/navidrome"
      tag        = "0.63.2@sha256:9012939114fbb1bb641b81cf96dec5ded15f0aafefe8d47a511d7cb919658e40" # renovate: datasource=docker depName=ghcr.io/navidrome/navidrome
    }
    litestream = {
      repository = "docker.io/litestream/litestream"
      tag        = "0.5.15@sha256:f45ca298a567bef6edd23d43429b5f80721473a9a9719e467f11d7888999403e" # renovate: datasource=docker depName=docker.io/litestream/litestream
    }
  }
  extra_configs = {
    ND_EXTAUTH_TRUSTEDSOURCES = join(",", [
      local.networks.kubernetes_pod.prefix,
    ])
    ND_ENABLEUSEREDITING  = false
    TZ                    = local.timezone
    ND_EXTAUTH_USERHEADER = "Remote-User"
    ND_SESSIONTIMEOUT     = "24h"
  }
  ingress_hostname = local.endpoints.navidrome.ingress
  gateway_ref = {
    name      = local.endpoints.cilium.name
    namespace = local.endpoints.cilium.namespace
  }
  auth_backend_ref = {
    name      = local.endpoints.authelia.name
    namespace = local.endpoints.authelia.namespace
    port      = 80
  }
  minio_endpoint    = "https://${local.endpoints.minio.service}:${local.service_ports.minio}"
  minio_data_bucket = "music"
  minio_bucket      = "navidrome"
  minio_user        = minio_iam_user.navidrome
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

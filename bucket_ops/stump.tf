resource "minio_s3_bucket" "stump" {
  bucket         = "stump"
  acl            = "private"
  force_destroy  = true
  object_locking = false
}

resource "minio_iam_user" "stump" {
  name          = "stump"
  force_destroy = true
}

resource "minio_iam_policy" "stump" {
  name = "stump"
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
          minio_s3_bucket.stump.arn,
          "${minio_s3_bucket.stump.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "stump" {
  user_name   = minio_iam_user.stump.id
  policy_name = minio_iam_policy.stump.id
}

module "stump" {
  source    = "./modules/stump"
  name      = "stump"
  namespace = "default"
  replicas  = 1
  images = {
    stump = {
      repository = "docker.io/aaronleopold/stump"
      tag        = "0.1.6@sha256:5a01c8d1c1ade887a9796ed01521350a9e12062e28da170de8b7fdbecfdb5454" # renovate: datasource=docker depName=docker.io/aaronleopold/stump
    }
    litestream = {
      repository = "docker.io/litestream/litestream"
      tag        = "0.5.16@sha256:f085f8bce71a5ad4ce8e28b28ea522de1d9e0d7dd0af3ea5c1bd626d0f341954" # renovate: datasource=docker depName=docker.io/litestream/litestream
    }
  }
  extra_envs = {
    STUMP_OIDC_ISSUER_URL    = "https://${local.httproutes.authelia.hostname}"
    STUMP_OIDC_CLIENT_ID     = local.authelia_oidc_clients.stump.client_id
    STUMP_OIDC_CLIENT_SECRET = local.authelia_oidc_clients.stump.client_secret
    STUMP_OIDC_SCOPES        = join(",", local.authelia_oidc_clients.stump.scopes)
  }
  ingress_hostname = local.httproutes.stump.hostname
  gateway_ref = {
    name      = local.services.cilium.name
    namespace = local.services.cilium.namespace
  }
  minio_endpoint    = "https://${local.services.minio.name}.${local.services.minio.namespace}:${local.service_ports.minio}"
  minio_data_bucket = "ebooks"
  minio_bucket      = "stump"
  minio_user        = minio_iam_user.stump
}

resource "minio_s3_object" "fluxcd-stump" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.stump.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "stump/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}
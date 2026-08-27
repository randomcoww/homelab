resource "minio_s3_bucket" "zot" {
  bucket         = "zot"
  acl            = "private"
  force_destroy  = true
  object_locking = false
}

resource "minio_iam_user" "zot" {
  name          = "zot"
  force_destroy = true
}

resource "minio_iam_policy" "zot" {
  name = "zot"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads",
        ]
        Resource = [
          minio_s3_bucket.zot.arn,
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
        ]
        Resource = [
          "${minio_s3_bucket.zot.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "zot" {
  user_name   = minio_iam_user.zot.id
  policy_name = minio_iam_policy.zot.id
}

module "zot" {
  source    = "./modules/zot"
  name      = "zot"
  namespace = "zot"

  service_hostname = local.endpoints.zot.hostname
  service_port     = local.service_ports.zot
  service_ip       = local.networks.service.vips.zot
  ca_issuer_name   = local.cert_issuers.ca_internal
  minio_endpoint   = "https://${local.networks.service.vips.minio}:${local.service_ports.minio}" # needs to be reachable and resolvable from host
  minio_bucket     = "zot"
  minio_user       = minio_iam_user.zot
}

resource "minio_s3_object" "fluxcd-zot" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.zot.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "zot/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}
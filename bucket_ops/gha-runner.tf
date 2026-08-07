resource "minio_iam_user" "gha-runner" {
  name          = "gha-runner"
  force_destroy = true
}

resource "minio_iam_policy" "gha-runner" {
  name = "gha-runner"
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
          minio_s3_bucket.static-bucket["boot"].arn,        # shared bucket for netboot
          "${minio_s3_bucket.static-bucket["boot"].arn}/*", # shared bucket for netboot
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "gha-runner" {
  user_name   = minio_iam_user.gha-runner.id
  policy_name = minio_iam_policy.gha-runner.id
}

module "gha-runner" {
  source               = "./modules/gha-runner"
  name                 = "gha"
  namespace            = "arc-runners"
  controller_namespace = "arc-systems"
  images = {
    gha-runner = {
      repository = "ghcr.io/actions/actions-runner"
      tag        = "2.336.0@sha256:0cfdcc701ce933c6d243c6b0b2da767366dc9f2e99961d4c3754b0b78084cdda" # renovate: datasource=docker depName=ghcr.io/actions/actions-runner
    }
  }
  github_credentials = {
    username = var.github_username
    token    = var.github_token
  }
  ca_issuer_name    = local.cert_issuers.ca_internal
  registry_endpoint = "${local.httproutes.registry.hostname}:${local.service_ports.registry}"
  minio_endpoint    = "${local.services.minio.name}.${local.services.minio.namespace}:${local.service_ports.minio}"
  minio_user        = minio_iam_user.gha-runner
}

resource "minio_s3_object" "fluxcd-gha-runner" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.gha-runner.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "gha-runner/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}
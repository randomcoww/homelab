# internal registry

resource "minio_s3_bucket" "registry" {
  bucket         = "registry"
  acl            = "private"
  force_destroy  = false
  object_locking = false
}

resource "minio_iam_user" "registry" {
  name          = "registry"
  force_destroy = true
}

resource "minio_iam_policy" "registry" {
  name = "registry"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*",
        ]
        Resource = [
          minio_s3_bucket.registry.arn,
          "${minio_s3_bucket.registry.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "registry" {
  user_name   = minio_iam_user.registry.id
  policy_name = minio_iam_policy.registry.id
}

module "registry" {
  source    = "./modules/registry"
  name      = local.endpoints.registry.name
  namespace = local.endpoints.registry.namespace
  replicas  = 2
  images = {
    registry = {
      repository = "ghcr.io/distribution/distribution"
      tag        = "3.1.1@sha256:bca24727f4002e51f959c18c42e816e4d1078198081a9837e16b8b7d7e43ebf8" # renovate: datasource=docker depName=ghcr.io/distribution/distribution
    }
  }
  ca_issuer_name      = local.cert_issuers.ca_internal
  minio_endpoint      = "${local.endpoints.minio.service_ip}:${local.service_ports.minio}" # needs to be reachable and resolvable from host
  minio_bucket        = "registry"
  minio_bucket_prefix = "/"
  minio_user          = minio_iam_user.registry
  service_port        = local.service_ports.registry
  service_hostname    = local.endpoints.registry.service
  service_ip          = local.endpoints.registry.service_ip
}

resource "minio_s3_object" "fluxcd-registry" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.registry.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "registry/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}
resource "minio_iam_user" "mountpoint-s3-csi" {
  name          = "mountpoint-s3-csi"
  force_destroy = true
}

resource "minio_iam_policy" "mountpoint-s3-csi" {
  name = "mountpoint-s3-csi"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          minio_s3_bucket.static-bucket["music"].arn,
          "${minio_s3_bucket.static-bucket["music"].arn}/*",
          minio_s3_bucket.static-bucket["ebooks"].arn,
          "${minio_s3_bucket.static-bucket["ebooks"].arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "mountpoint-s3-csi" {
  user_name   = minio_iam_user.mountpoint-s3-csi.id
  policy_name = minio_iam_policy.mountpoint-s3-csi.id
}

module "mountpoint-s3-csi" {
  source    = "./modules/mountpoint-s3-csi"
  name      = "s3-csi"
  namespace = "s3-csi"
  images = {
    mountpoint-s3-csi = {
      repository = "reg.cluster.internal/randomcoww/mountpoint-s3-csi"
      tag        = "v2.7.0.1785766438@sha256:0ede523b2792da2141066a147b8972078702791262fdfb9c3b079fd3af4ce386" # renovate: datasource=docker depName=reg.cluster.internal/randomcoww/mountpoint-s3-csi
    }
  }
  kubelet_root_path = local.kubernetes.kubelet_root_path
  minio_user        = minio_iam_user.mountpoint-s3-csi
}

resource "minio_s3_object" "fluxcd-mountpoint-s3-csi" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.mountpoint-s3-csi.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "mountpoint-s3-csi/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}

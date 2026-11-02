resource "minio_s3_bucket" "stump" {
  bucket         = "stump"
  acl            = "private"
  force_destroy  = true
  object_locking = false
}

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
      repository = "zot.cluster.internal/randomcoww/mountpoint-s3-csi"
      tag        = "v2.9.2.1793653200@sha256:8f42614dbe4b1cd6171fc17bf82ca2432ddc61072ea6b3b1b99f8bbfd37e8bd0" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/mountpoint-s3-csi
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

resource "minio_s3_bucket" "bucket" {
  for_each = local.minio_buckets

  bucket         = each.key
  acl            = lookup(each.value, "acl", "private")
  force_destroy  = lookup(each.value, "force_destroy", false)
  object_locking = lookup(each.value, "object_locking", false)
}

resource "minio_iam_user" "user" {
  for_each = local.minio_users

  name          = each.key
  force_destroy = true
}

resource "minio_iam_policy" "policy" {
  for_each = local.minio_users

  name = each.key
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for _, policy in each.value.policies :
      {
        Effect = policy.Effect
        Action = policy.Action
        Resource = flatten([
          for _, bucket in policy.buckets :
          [
            minio_s3_bucket.bucket[bucket].arn,
            "${minio_s3_bucket.bucket[bucket].arn}/*",
          ]
        ])
      }
    ]
  })
}

resource "minio_iam_user_policy_attachment" "policy" {
  for_each = local.minio_users

  user_name   = minio_iam_user.user[each.key].id
  policy_name = minio_iam_policy.policy[each.key].id
}

module "minio-user-secret-fluxcd" {
  source    = "../modules/secret"
  name      = "${local.endpoints.fluxcd.name}-bucket"
  namespace = local.endpoints.fluxcd.namespace
  app       = local.endpoints.fluxcd.name
  release   = "0.1.0"
  data = merge({
    accesskey = minio_iam_user.user["fluxcd"].id
    secretkey = minio_iam_user.user["fluxcd"].secret
  })
}
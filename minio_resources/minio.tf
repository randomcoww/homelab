resource "minio_s3_bucket" "bucket" {
  for_each = local.minio_buckets

  bucket        = each.key
  acl           = each.value.acl
  force_destroy = each.value.force_destroy
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

module "minio-user-secret" {
  for_each = local.minio_users

  source  = "../modules/secret"
  name    = each.value.secret
  app     = each.key
  release = "0.1.0"
  data = merge({
    AWS_ACCESS_KEY_ID     = minio_iam_user.user[each.key].id
    AWS_SECRET_ACCESS_KEY = minio_iam_user.user[each.key].secret
    AWS_CA_BUNDLE         = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
  })
}

resource "helm_release" "minio-user-secret" {
  for_each = local.minio_users

  chart         = "../helm-wrapper"
  name          = each.value.secret
  namespace     = each.value.namespace
  wait          = false
  wait_for_jobs = false
  max_history   = 2
  values = [
    yamlencode({
      manifests = [
        module.minio-user-secret[each.key].manifest,
      ]
    })
  ]
}

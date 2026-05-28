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

module "minio-user-secret" {
  for_each = local.minio_users

  source  = "../modules/secret"
  name    = each.value.secret
  app     = each.key
  release = "0.1.0"
  data = merge({
    AWS_ACCESS_KEY_ID     = minio_iam_user.user[each.key].id
    AWS_SECRET_ACCESS_KEY = minio_iam_user.user[each.key].secret
    accesskey             = minio_iam_user.user[each.key].id
    secretkey             = minio_iam_user.user[each.key].secret
  })
}

resource "helm_release" "minio-user-secret" {
  for_each = local.minio_users

  chart            = "../helm-wrapper"
  name             = each.value.secret
  namespace        = each.value.namespace
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = [
        module.minio-user-secret[each.key].manifest,
      ]
    })
  ]
}

resource "helm_release" "fluxcd-bucket" {
  chart            = "../helm-wrapper"
  name             = "${local.endpoints.fluxcd.name}-bucket"
  namespace        = local.endpoints.fluxcd.namespace
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = [
        module.minio-tls.manifest,
        yamlencode({
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "Bucket"
          metadata = {
            name = "${local.endpoints.fluxcd.name}-bucket"
          }
          spec = {
            interval = "10s"
            provider = "generic"
            endpoint = data.terraform_remote_state.helm.outputs.minio.endpoint
            secretRef = {
              name = local.minio_users.fluxcd.secret
            }
            bucketName = "fluxcd"
            certSecretRef = {
              name = "${local.endpoints.fluxcd.name}-minio-client-tls"
            }
          }
        }),
        yamlencode({
          apiVersion = "kustomize.toolkit.fluxcd.io/v1"
          kind       = "Kustomization"
          metadata = {
            name = "${local.endpoints.fluxcd.name}-bucket"
          }
          spec = {
            interval = "1m"
            sourceRef = {
              kind = "Bucket"
              name = "${local.endpoints.fluxcd.name}-bucket"
            }
            path    = "./"
            prune   = true
            wait    = true
            timeout = "5m"
          }
        }),
      ]
    }),
  ]
}
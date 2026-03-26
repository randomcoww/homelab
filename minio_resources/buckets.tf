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
  })
}

resource "helm_release" "minio-user-secret" {
  chart                      = "../helm-wrapper"
  name                       = "minio-user-secret"
  namespace                  = "flux-runners"
  create_namespace           = true
  wait                       = false
  wait_for_jobs              = false
  max_history                = 1
  disable_crd_hooks          = true
  disable_webhooks           = true
  disable_openapi_validation = true
  skip_crds                  = true
  replace                    = true
  render_subchart_notes      = false
  values = [
    yamlencode({ manifests = [
      for k, v in local.minio_users :
      yamlencode({
        apiVersion = "helm.toolkit.fluxcd.io/v2"
        kind       = "HelmRelease"
        metadata = {
          name      = v.secret
          namespace = v.namespace
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chart = {
            spec = {
              chart = "helm-wrapper"
              sourceRef = {
                kind      = "HelmRepository"
                name      = "wrapper"
                namespace = "flux-runners"
              }
              interval = "5m"
            }
          }
          releaseName = v.secret
          install = {
            remediation = {
              retries = -1
            }
          }
          upgrade = {
            remediation = {
              retries = -1
            }
          }
          test = {
            enable = false
          }
          values = {
            manifests = [
              module.minio-user-secret[k].manifest,
            ]
          }
        }
      })
      ]
    })
  ]
}

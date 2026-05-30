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
  source  = "../modules/secret"
  name    = "${local.endpoints.fluxcd.name}-bucket"
  app     = local.endpoints.fluxcd.name
  release = "0.1.0"
  data = merge({
    accesskey = minio_iam_user.user.fluxcd.id
    secretkey = minio_iam_user.user.fluxcd.secret
  })
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
        module.minio-user-secret-fluxcd.manifest,
        module.minio-tls.manifest,

        yamlencode({
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "Bucket"
          metadata = {
            name = "${local.endpoints.fluxcd.name}-bucket"
            annotations = {
              "checksum/minio-user-secret" = sha256(module.minio-user-secret-fluxcd.manifest)
              "checksum/tls"               = sha256(module.minio-tls.manifest)
            }
          }
          spec = {
            interval = "10s"
            provider = "generic"
            endpoint = data.terraform_remote_state.bootstrap.outputs.minio.endpoint
            secretRef = {
              name = module.minio-user-secret-fluxcd.name
            }
            bucketName = "fluxcd"
            certSecretRef = {
              name = module.minio-tls.name
            }
          }
        }),

        # resources that include CRD
        yamlencode({
          apiVersion = "kustomize.toolkit.fluxcd.io/v1"
          kind       = "Kustomization"
          metadata = {
            name = "${local.endpoints.fluxcd.name}-bucket-crd"
          }
          spec = {
            interval = "1m"
            sourceRef = {
              kind = "Bucket"
              name = "${local.endpoints.fluxcd.name}-bucket"
            }
            path    = "./crd"
            prune   = true
            wait    = true
            timeout = "5m"
          }
        }),

        # lower level services
        yamlencode({
          apiVersion = "kustomize.toolkit.fluxcd.io/v1"
          kind       = "Kustomization"
          metadata = {
            name = "${local.endpoints.fluxcd.name}-bucket-system"
          }
          spec = {
            interval = "1m"
            sourceRef = {
              kind = "Bucket"
              name = "${local.endpoints.fluxcd.name}-bucket"
            }
            dependsOn = [
              {
                name = "${local.endpoints.fluxcd.name}-bucket-crd"
              },
            ]
            path    = "./system"
            prune   = true
            wait    = true
            timeout = "5m"
          }
        }),

        # service
        yamlencode({
          apiVersion = "kustomize.toolkit.fluxcd.io/v1"
          kind       = "Kustomization"
          metadata = {
            name = "${local.endpoints.fluxcd.name}-bucket-service"
          }
          spec = {
            interval = "1m"
            sourceRef = {
              kind = "Bucket"
              name = "${local.endpoints.fluxcd.name}-bucket"
            }
            dependsOn = [
              {
                name = "${local.endpoints.fluxcd.name}-bucket-crd"
              },
            ]
            path    = "./service"
            prune   = true
            wait    = true
            timeout = "5m"
          }
        }),
      ]
    }),
  ]
}
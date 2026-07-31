resource "minio_iam_user" "fluxcd" {
  name          = "fluxcd"
  force_destroy = true
}

resource "minio_iam_policy" "fluxcd" {
  name = "fluxcd"
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
          minio_s3_bucket.static-bucket["fluxcd"].arn,
          "${minio_s3_bucket.static-bucket["fluxcd"].arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "fluxcd" {
  user_name   = minio_iam_user.fluxcd.id
  policy_name = minio_iam_policy.fluxcd.id
}

module "minio-user-secret-fluxcd" {
  source    = "../modules/secret"
  name      = "${local.endpoints.fluxcd.name}-minio-user-secret"
  namespace = local.endpoints.fluxcd.namespace
  app       = local.endpoints.fluxcd.name
  release   = "0.1.0"
  data = merge({
    accesskey = minio_iam_user.fluxcd.id
    secretkey = minio_iam_user.fluxcd.secret
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
      manifests = concat([
        module.minio-user-secret-fluxcd.manifest,
        module.minio-tls.manifest,
        ], [

        # source bucket reference
        yamlencode({
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "Bucket"
          metadata = {
            name = "${local.endpoints.fluxcd.name}-bucket"
          }
          spec = {
            interval = "10s"
            provider = "generic"
            endpoint = "${local.endpoints.minio.service}:${local.service_ports.minio}"
            secretRef = {
              name = module.minio-user-secret-fluxcd.name
            }
            bucketName = "fluxcd"
            certSecretRef = {
              name = module.minio-tls.name
            }
          }
        })
        ], [

        # kustomization for each service
        for k, dependencies in {
          kubelet-csr-approver   = []
          node-feature-discovery = []
          cloudnative-pg         = []
          tailscale-operator     = []
          tailscale-crs          = ["tailscale-operator"]
          cilium-crs             = []
          cert-manager-crs       = []
          k8s-gateway            = []
          metrics-server         = []
          amd-gpu                = []
          device-plugin          = []
          kured                  = []
          reloader               = []
          prometheus             = []
          registry               = []
          kea                    = []
          juicefs-csi-driver     = []
          mountpoint-s3-csi      = []
          cloudflare-tunnel      = []
          lldap                  = []
          authelia               = []
          gha-runner             = []
          llama-cpp              = []
          camofox-browser        = []
          searxng                = []
          kubernetes-mcp         = []
          hermes-agent           = ["juicefs-csi-driver", "cloudnative-pg"]
          stump                  = ["mountpoint-s3-csi", "juicefs-csi-driver", "cloudnative-pg"]
          navidrome              = ["mountpoint-s3-csi"]
        } :
        yamlencode({
          apiVersion = "kustomize.toolkit.fluxcd.io/v1"
          kind       = "Kustomization"
          metadata = {
            name = k
          }
          spec = {
            interval = "1m"
            sourceRef = {
              kind = "Bucket"
              name = "${local.endpoints.fluxcd.name}-bucket"
            }
            dependsOn = [
              for _, dep in dependencies :
              {
                name = dep
              }
            ]
            path    = "./${k}"
            prune   = true
            wait    = true
            timeout = "5m"
          }
        })
      ])
    }),
  ]
}
locals {
  fluxcd_name      = "fluxcd"
  fluxcd_namespace = "flux-system"
}

resource "minio_iam_user" "fluxcd" {
  name          = local.fluxcd_name
  force_destroy = true
}

resource "minio_iam_policy" "fluxcd" {
  name = local.fluxcd_name
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
  name      = "${local.fluxcd_name}-minio-user-secret"
  namespace = local.fluxcd_namespace
  app       = local.fluxcd_name
  release   = "0.1.0"
  data = merge({
    accesskey = minio_iam_user.fluxcd.id
    secretkey = minio_iam_user.fluxcd.secret
  })
}

resource "helm_release" "fluxcd" {
  name             = local.fluxcd_name
  namespace        = local.fluxcd_namespace
  repository       = "https://fluxcd-community.github.io/helm-charts"
  chart            = "flux2"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "2.19.0"
  timeout          = local.kubernetes.helm_release_timeout
  max_history      = 2
  values = [
    yamlencode({
      clusterDomain = local.domains.kubernetes
      helmController = {
        create = true
        resources = {
          limits = {
            memory = "256Mi"
          }
          requests = {
            memory = "180Mi"
          }
        }
      }
      kustomizeController = {
        create = true
        resources = {
          limits = {
            memory = "384Mi"
          }
          requests = {
            memory = "256Mi"
          }
        }
      }
      sourceController = {
        create = true
        resources = {
          limits = {
            memory = "256Mi"
          }
          requests = {
            memory = "180Mi"
          }
        }
      }
      imageAutomationController = {
        create = false
      }
      imageReflectionController = {
        create = false
      }
      notificationController = {
        create = false
      }
    }),
  ]
}

resource "helm_release" "fluxcd-bucket" {
  chart            = "../helm-wrapper"
  name             = "${local.fluxcd_name}-bucket"
  namespace        = local.fluxcd_namespace
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
            name = "${local.fluxcd_name}-bucket"
          }
          spec = {
            interval = "10s"
            provider = "generic"
            endpoint = "${local.services.minio.name}.${local.services.minio.namespace}:${local.service_ports.minio}"
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
          dragonfly-operator     = []
          tailscale-operator     = []
          tailscale-crs          = ["tailscale-operator"]
          cilium-crs             = []
          cert-manager-crs       = []
          k8s-gateway            = []
          metrics-server         = []
          amd-gpu                = []
          resource-claims        = ["amd-gpu"]
          device-plugin          = []
          kured                  = []
          reloader               = []
          victoria-metrics       = []
          kea                    = []
          juicefs-csi-driver     = ["cloudnative-pg"]
          mountpoint-s3-csi      = []
          cloudflare-tunnel      = []
          lldap                  = ["cloudnative-pg"]
          authelia               = ["dragonfly-operator", "lldap"]
          gha-runner             = []
          llama-cpp              = ["resource-claims"]
          camofox-browser        = []
          searxng                = []
          kubernetes-mcp         = []
          hindsight              = ["cloudnative-pg"]
          hermes-agent           = ["juicefs-csi-driver"]
          stump                  = ["mountpoint-s3-csi", "juicefs-csi-driver"]
          navidrome              = ["mountpoint-s3-csi"]
          hostapd                = ["node-feature-discovery", "device-plugin"]
          sunshine-desktop       = ["device-plugin", "resource-claims"]
          generate-backup-disk   = []
          zot                    = []
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
              name = "${local.fluxcd_name}-bucket"
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
  depends_on = [
    helm_release.fluxcd,
  ]
}
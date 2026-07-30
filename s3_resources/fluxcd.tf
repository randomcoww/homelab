# remaining kubernetes resources for flux operation

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
          hostapd                = []
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
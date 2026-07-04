output "manifests" {
  value = concat([
    module.minio-user-secret.manifest,
    ], [
    for _, m in [
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "HelmRepository"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          url      = "https://awslabs.github.io/mountpoint-s3-csi-driver"
        }
      },
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2"
        kind       = "HelmRelease"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chart = {
            spec = {
              chart   = "aws-mountpoint-s3-csi-driver"
              version = "2.7.0" # renovate: datasource=helm depName=aws-mountpoint-s3-csi-driver registryUrl=https://awslabs.github.io/mountpoint-s3-csi-driver
              sourceRef = {
                kind = "HelmRepository"
                name = var.name
              }
              interval = "5m"
            }
          }
          releaseName = var.name
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
            image = {
              repository = var.images.mountpoint_s3_csi.repository
              tag        = var.images.mountpoint_s3_csi.tag
            }
            node = {
              kubeletPath = var.kubelet_root_path
            }
            supportLegacySystemDMounts = false
            # TODO: update credentials handling https://github.com/awslabs/mountpoint-s3-csi-driver/issues/334
            awsAccessSecret = {
              name      = module.minio-user-secret.name
              keyId     = "AWS_ACCESS_KEY_ID"
              accessKey = "AWS_SECRET_ACCESS_KEY"
            }
          }
        }
      },
    ] :
    yamlencode(m)
  ])
}
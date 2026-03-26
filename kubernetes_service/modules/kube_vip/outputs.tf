output "releases" {
  value = [
    for _, m in [
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
              chart = "helm-wrapper"
              sourceRef = {
                kind      = "HelmRepository"
                name      = "wrapper"
                namespace = "flux-runners"
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
            manifests = local.manifests
          }
        }
      },
    ] :
    yamlencode(m)
  ]
}
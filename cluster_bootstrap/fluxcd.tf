resource "helm_release" "fluxcd" {
  name             = local.endpoints.fluxcd.name
  namespace        = local.endpoints.fluxcd.namespace
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
  depends_on = [
    kubernetes_labels.labels,
    helm_release.prometheus-operator-crds,
  ]
}
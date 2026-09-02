# VictoriaMetrics is used, but keep this to allow many helm to deploy ServiceMonitor CRDs
resource "helm_release" "prometheus-crds" {
  name             = "prometheus-crds"
  namespace        = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus-operator-crds"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "31.0.1"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
    }),
  ]
}

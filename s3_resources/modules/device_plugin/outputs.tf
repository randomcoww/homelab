output "manifests" {
  value = concat([
    module.daemonset.manifest,
    ], [
    for _, m in [
      {
        apiVersion = "monitoring.coreos.com/v1"
        kind       = "PodMonitor"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          selector = {
            matchLabels = {
              app = var.name
            }
          }
          podMetricsEndpoints = [
            {
              path       = "/metrics"
              portNumber = var.metrics_port
            },
          ]
        }
      },
    ] :
    yamlencode(m)
  ])
}
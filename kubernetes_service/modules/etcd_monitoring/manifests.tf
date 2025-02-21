module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = {
    "templates/service.yaml" = module.service.manifest
  }
}

module "service" {
  source  = "../../../modules/service"
  name    = var.name
  app     = var.name
  release = var.release
  annotations = {
    "prometheus.io/scrape" = "true"
    "prometheus.io/port"   = tostring(var.ports.etcd_metrics)
  }
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "metrics"
        port       = var.ports.etcd_metrics
        protocol   = "TCP"
        targetPort = var.ports.etcd_metrics
      },
    ]
  }
}
module "service" {
  source  = "../../../modules/service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    externalIPs = [
      var.service_ip,
    ]
    ports = [
      {
        name       = var.name
        port       = var.ports.apiserver
        protocol   = "TCP"
        targetPort = var.ports.apiserver
      },
    ]
  }
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = {
    "templates/kube-apiserver-service.yaml" = module.service.manifest
  }
}
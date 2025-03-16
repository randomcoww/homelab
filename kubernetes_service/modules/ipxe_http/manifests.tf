module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.ipxe_http)[1]
  manifests = {
    "templates/deployment.yaml" = module.deployment.manifest
    "templates/service.yaml"    = module.service.manifest
  }
}

module "service" {
  source  = "../../../modules/service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type              = "LoadBalancer"
    loadBalancerClass = var.loadbalancer_class_name
    ports = [
      {
        name       = "HTTP"
        port       = var.ports.ipxe_http
        protocol   = "TCP"
        targetPort = 80
      },
    ]
  }
}

module "deployment" {
  source   = "../../../modules/deployment"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = var.replicas
  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.ipxe_http
      },
    ]
  }
}
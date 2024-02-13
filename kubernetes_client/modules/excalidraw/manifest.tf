module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.excalidraw)[1]
  manifests = {
    "templates/service.yaml"    = module.service.manifest
    "templates/ingress.yaml"    = module.ingress.manifest
    "templates/deployment.yaml" = module.deployment.manifest
  }
}

module "service" {
  source  = "../service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "excalidraw"
        port       = var.ports.excalidraw
        protocol   = "TCP"
        targetPort = 80
      },
    ]
  }
}

module "ingress" {
  source             = "../ingress"
  name               = var.name
  app                = var.name
  release            = var.release
  ingress_class_name = var.ingress_class_name
  annotations        = var.nginx_ingress_annotations
  rules = [
    {
      host = var.service_hostname
      paths = [
        {
          service = var.name
          port    = var.ports.excalidraw
          path    = "/"
        },
      ]
    },
  ]
}

module "deployment" {
  source   = "../deployment"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  spec = {
    containers = [
      {
        name  = var.name
        image = var.images.excalidraw
        ports = [
          {
            containerPort = 80
          },
        ]
      },
    ]
  }
}
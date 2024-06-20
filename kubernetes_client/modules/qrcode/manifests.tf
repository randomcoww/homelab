module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.qrcode)[1]
  manifests = merge({
    "templates/service.yaml"    = module.service.manifest
    "templates/ingress.yaml"    = module.ingress.manifest
    "templates/deployment.yaml" = module.deployment.manifest
    }, {
    for k, v in var.qrcodes :
    "templates/ingress-${k}.yaml" => module.ingress-qrcodes[k].manifest
  })
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
        name = "qrcode"
        port = var.ports.qrcode
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
          service = module.service.name
          port    = var.ports.qrcode
          path    = "/"
        },
      ]
    },
  ]
}

module "ingress-qrcodes" {
  for_each = var.qrcodes

  source             = "../ingress"
  name               = "${var.name}-${each.key}"
  app                = var.name
  release            = var.release
  ingress_class_name = var.ingress_class_name
  annotations = merge(var.nginx_ingress_annotations, {
    "nginx.ingress.kubernetes.io/rewrite-target" = "https://${var.service_hostname}?q=${base64encode(each.value.code)}"
  })
  rules = [
    {
      host = each.value.service_hostname
      paths = [
        {
          service = module.service.name
          port    = var.ports.qrcode
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
  replicas = var.replicas
  spec = {
    containers = [
      {
        name  = var.name
        image = var.images.qrcode
        ports = [
          {
            containerPort = var.ports.qrcode
          },
        ]
      },
    ]
  }
}
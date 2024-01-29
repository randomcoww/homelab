module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.alpaca_stream)[1]
  manifests = {
    "templates/secret.yaml"     = module.secret.manifest
    "templates/service.yaml"    = module.service.manifest
    "templates/deployment.yaml" = module.deployment.manifest
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    APCA_API_KEY_ID     = var.alpaca_api_key_id
    APCA_API_SECRET_KEY = var.alpaca_api_secret_key
    APCA_API_BASE_URL   = var.alpaca_api_base_url
  }
}

module "service" {
  source  = "../service"
  name    = var.name
  app     = var.name
  release = var.release
  annotations = {
    "external-dns.alpha.kubernetes.io/hostname" = var.service_hostname
  }
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "alpaca-stream"
        port       = var.ports.alpaca_stream
        protocol   = "TCP"
        targetPort = var.ports.alpaca_stream
      },
    ]
  }
}

module "deployment" {
  source   = "../deployment"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    containers = [
      {
        name  = var.name
        image = var.images.alpaca_stream
        args = [
          "-listen-url",
          "0.0.0.0:${var.ports.alpaca_stream}",
        ]
        envFrom : [
          {
            secretRef = {
              name = var.name
            }
          },
        ]
        ports = [
          {
            containerPort = var.ports.alpaca_stream
          },
        ]
      },
    ]
  }
}
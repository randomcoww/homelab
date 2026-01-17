
locals {
  mcp_port = 8080
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = {
    "templates/deployment.yaml" = module.deployment.manifest
    "templates/service.yaml"    = module.service.manifest
    "templates/ingress.yaml"    = module.ingress.manifest
    "templates/serviceaccount.yaml" = yamlencode({
      apiVersion = "v1"
      kind       = "ServiceAccount"
      metadata = {
        name = var.name
        labels = {
          app     = var.name
          release = var.release
        }
      }
    })
    "templates/clusterrole.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "ClusterRole"
      metadata = {
        name = var.name
        labels = {
          app     = var.name
          release = var.release
        }
      }
      rules = [
        {
          apiGroups = ["*"]
          resources = ["*"]
          verbs     = ["list", "watch", "get"]
        },
      ]
    })
    "templates/clusterrolebinding.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "ClusterRoleBinding"
      metadata = {
        name = var.name
        labels = {
          app     = var.name
          release = var.release
        }
      }
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "ClusterRole"
        name     = var.name
      }
      subjects = [
        {
          kind      = "ServiceAccount"
          name      = var.name
          namespace = var.namespace
        },
      ]
    })
  }
}

module "service" {
  source  = "../../../modules/service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "mcp"
        port       = local.mcp_port
        protocol   = "TCP"
        targetPort = local.mcp_port
      },
    ]
  }
}

module "ingress" {
  source             = "../../../modules/ingress"
  name               = var.name
  app                = var.name
  release            = var.release
  ingress_class_name = var.ingress_class_name
  annotations        = var.nginx_ingress_annotations
  rules = [
    {
      host = var.ingress_hostname
      paths = [
        {
          service = module.service.name
          port    = local.mcp_port
          path    = "/"
        },
      ]
    },
  ]
}

module "deployment" {
  source   = "../../../modules/deployment"
  name     = var.name
  app      = var.name
  release  = var.release
  replicas = var.replicas
  affinity = var.affinity
  template_spec = {
    serviceAccountName = var.name
    resources = {
      requests = {
        memory = "128Mi"
      }
      limits = {
        memory = "128Mi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.kubernetes_mcp
        ports = [
          {
            containerPort = local.mcp_port
          },
        ]
        args = [
          "--port",
          tostring(local.mcp_port),
          "--disable-multi-cluster",
          "--disable-destructive",
          "--sse-base-url",
          "https://${var.ingress_hostname}",
        ]
      },
    ]
  }
}
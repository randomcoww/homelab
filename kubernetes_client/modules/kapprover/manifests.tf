locals {
  serviceaccount = {
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name = var.name
      labels = {
        app     = var.name
        release = var.release
      }
    }
  }

  role = {
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
        apiGroups = ["certificates.k8s.io"]
        resources = ["certificatesigningrequests"]
        verbs     = ["get", "list", "delete", "watch"]
      },
      {
        apiGroups = ["certificates.k8s.io"]
        resources = ["certificatesigningrequests/approval"]
        verbs     = ["update"]
      },
      {
        apiGroups     = ["certificates.k8s.io"]
        resources     = ["signers"]
        resourceNames = ["kubernetes.io/kubelet-serving"]
        verbs         = ["approve"]
      },
    ]
  }

  rolebinding = {
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
  }
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.kapprover)[1]
  manifests = {
    "templates/serviceaccount.yaml"     = yamlencode(local.serviceaccount)
    "templates/clusterrole.yaml"        = yamlencode(local.role)
    "templates/clusterrolebinding.yaml" = yamlencode(local.rolebinding)
    "templates/deployment.yaml"         = module.deployment.manifest
  }
}

module "deployment" {
  source   = "../deployment"
  name     = var.name
  app      = var.name
  release  = var.release
  replicas = var.replicas
  spec = {
    priorityClassName  = "system-cluster-critical"
    serviceAccountName = var.name
    containers = [
      {
        name  = var.name
        image = var.images.kapprover
        resources = {
          requests = {
            cpu    = "100m"
            memory = "50Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "50Mi"
          }
        }
      },
    ]
  }
}
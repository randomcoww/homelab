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
      annotations = {
        "rbac.authorization.kubernetes.io/autoupdate" = "true"
      }
    }
    rules = [
      {
        apiGroups = ["coordination.k8s.io"]
        resources = ["leases"]
        verbs     = ["get", "create", "update", "list", "put"]
      },
      {
        apiGroups = [""]
        resources = ["configmaps", "endpoints", "events", "services/status", "leases"]
        verbs     = ["*"]
      },
      {
        apiGroups = [""]
        resources = ["nodes", "services"]
        verbs     = ["list", "get", "watch", "update"]
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
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.kube_vip_cloud_provider)[1]
  manifests = {
    "templates/serviceaccount.yaml"     = yamlencode(local.serviceaccount)
    "templates/clusterrole.yaml"        = yamlencode(local.role)
    "templates/clusterrolebinding.yaml" = yamlencode(local.rolebinding)
    "templates/deployment.yaml"         = module.deployment.manifest
    "templates/configmap.yaml"          = module.configmap.manifest
  }
}

module "deployment" {
  source   = "../../../modules/deployment"
  name     = var.name
  app      = var.name
  replicas = var.replicas
  release  = var.release
  affinity = var.affinity
  template_spec = {
    serviceAccountName = var.name
    tolerations = [
      {
        operator = "Exists"
        effect   = "NoSchedule"
      },
    ]
    containers = [
      {
        name  = var.name
        image = var.images.kube_vip_cloud_provider
        command = [
          "/kube-vip-cloud-provider",
          "--leader-elect-resource-name=${var.name}",
          "--secure-port=0",
        ]
      },
    ]
  }
}

module "configmap" {
  source  = "../../../modules/configmap"
  name    = "kubevip"
  app     = var.name
  release = var.release
  data    = var.ip_pools
}
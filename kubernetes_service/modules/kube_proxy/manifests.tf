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

  rolebinding = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "system:kube-proxy"
      labels = {
        app     = var.name
        release = var.release
      }
    }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "system:node-proxier"
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
  app_version = split(":", var.images.kube_proxy)[1]
  manifests = {
    "templates/serviceaccount.yaml"     = yamlencode(local.serviceaccount)
    "templates/clusterrolebinding.yaml" = yamlencode(local.rolebinding)
    "templates/configmap.yaml"          = module.configmap.manifest
    "templates/daemonset.yaml"          = module.daemonset.manifest
  }
}

module "configmap" {
  source  = "../../../modules/configmap"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    "kube-proxy-config.yaml" = yamlencode({
      kind               = "KubeProxyConfiguration"
      apiVersion         = "kubeproxy.config.k8s.io/v1alpha1"
      mode               = "nftables"
      clusterCIDR        = var.kubernetes_pod_prefix
      healthzBindAddress = "127.0.0.1:${var.ports.kube_proxy}"
      featureGates = {
        NFTablesProxyMode = true
      }
    })
  }
}

module "daemonset" {
  source   = "../../../modules/daemonset"
  name     = var.name
  app      = var.name
  affinity = var.affinity
  release  = var.release
  annotations = {
    "checksum/configmap" = sha256(module.configmap.manifest)
  }
  template_spec = {
    priorityClassName  = "system-node-critical"
    hostNetwork        = true
    serviceAccountName = var.name
    tolerations = [
      {
        operator = "Exists"
        effect   = "NoExecute"
      },
      {
        operator = "Exists"
        effect   = "NoSchedule"
      },
    ]
    containers = [
      {
        name  = var.name
        image = var.images.kube_proxy
        command = [
          "kube-proxy",
          "--config=/etc/kube-proxy/kube-proxy-config.yaml",
          "--v=2",
        ]
        env = [
          {
            name  = "KUBERNETES_SERVICE_HOST"
            value = var.kube_apiserver_ip
          },
          {
            name  = "KUBERNETES_SERVICE_PORT"
            value = tostring(var.ports.kube_apiserver)
          },
        ]
        securityContext = {
          privileged = true
        }
        volumeMounts = [
          {
            name      = "modules"
            mountPath = "/lib/modules"
            readOnly  = true
          },
          {
            name      = "kube-proxy-config"
            mountPath = "/etc/kube-proxy"
          },
        ]
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.kube_proxy
            path   = "/healthz"
          }
        }
      },
    ]
    volumes = [
      {
        name = "modules"
        hostPath = {
          path = "/usr/lib/modules"
        }
      },
      {
        name = "kube-proxy-config"
        configMap = {
          name = module.configmap.name
        }
      },
    ]
  }
}
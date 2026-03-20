module "kube-proxy" {
  source    = "./modules/kube_proxy"
  name      = "kube-proxy"
  namespace = "kube-system"
  images = {
    kube_proxy = local.container_images_digest.kube_proxy
  }
  ports = {
    kube_proxy         = local.host_ports.kube_proxy
    kube_proxy_metrics = local.host_ports.kube_proxy_metrics
    kube_apiserver     = local.host_ports.apiserver
  }
  kubernetes_pod_prefix = local.networks.kubernetes_pod.prefix
  kube_apiserver_ip     = local.services.apiserver.ip
}

module "flannel" {
  source    = "./modules/flannel"
  name      = "flannel"
  namespace = "kube-system"
  images = {
    flannel            = local.container_images_digest.flannel
    flannel_cni_plugin = local.container_images_digest.flannel_cni_plugin
  }
  ports = {
    healthz = local.host_ports.flannel_healthz
  }
  kubernetes_pod_prefix     = local.networks.kubernetes_pod.prefix
  cni_bridge_interface_name = local.kubernetes.cni_bridge_interface_name
  cni_version               = "0.3.1"
  cni_bin_path              = local.kubernetes.cni_bin_path
  cni_config_path           = local.kubernetes.cni_config_path
}

# Bootstrap

resource "helm_release" "bootstrap" {
  chart            = "../helm-wrapper"
  name             = "bootstrap"
  namespace        = "kube-system"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({ manifests = [
      # https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/
      # enable bootstrapping nodes to create CSR
      yamlencode({
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind       = "ClusterRoleBinding"
        metadata = {
          name = "create-csrs-for-bootstrapping"
        }
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io"
          kind     = "ClusterRole"
          name     = "system:node-bootstrapper"
        }
        subjects = [
          {
            apiGroup = "rbac.authorization.k8s.io"
            kind     = "Group"
            name     = "system:bootstrappers"
          },
        ]
      }),

      # Approve all CSRs for the group "system:bootstrappers"
      yamlencode({
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind       = "ClusterRoleBinding"
        metadata = {
          name = "auto-approve-csrs-for-group"
        }
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io"
          kind     = "ClusterRole"
          name     = "system:certificates.k8s.io:certificatesigningrequests:nodeclient"
        }
        subjects = [
          {
            apiGroup = "rbac.authorization.k8s.io"
            kind     = "Group"
            name     = "system:bootstrappers"
          },
        ]
      }),

      # Approve renewal CSRs for the group "system:nodes"
      yamlencode({
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind       = "ClusterRoleBinding"
        metadata = {
          name = "auto-approve-renewals-for-nodes"
        }
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io"
          kind     = "ClusterRole"
          name     = "system:certificates.k8s.io:certificatesigningrequests:selfnodeclient"
        }
        subjects = [
          {
            apiGroup = "rbac.authorization.k8s.io"
            kind     = "Group"
            name     = "system:nodes"
          },
        ]
      }),

      # kube apiserver access to kubelet #
      # https://stackoverflow.com/questions/48118125/kubernetes-rbac-role-verbs-to-exec-to-pod
      yamlencode({
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind       = "ClusterRole"
        metadata = {
          name = "system:kube-apiserver-to-kubelet"
          annotations = {
            "rbac.authorization.kubernetes.io/autoupdate" = "true"
          }
          labels = {
            "kubernetes.io/bootstrapping" = "rbac-defaults"
          }
        }
        rules = [
          {
            apiGroups = [""]
            resources = ["nodes/proxy", "nodes/stats", "nodes/log", "nodes/spec", "nodes/metrics"]
            verbs     = ["*"]
          },
          {
            apiGroups = [""]
            resources = ["pods", "pods/log"]
            verbs     = ["get", "list"]
          },
          {
            apiGroups = [""]
            resources = ["pods/exec"]
            verbs     = ["create"]
          },
        ]
      }),

      yamlencode({
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind       = "ClusterRoleBinding"
        metadata = {
          name = "system:kube-apiserver"
        }
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io"
          kind     = "ClusterRole"
          name     = "system:kube-apiserver-to-kubelet"
        }
        subjects = [
          {
            apiGroup = "rbac.authorization.k8s.io"
            kind     = "User"
            name     = local.kubernetes.kubelet_client_user
          },
        ]
      }),
    ] }),
  ]
}

resource "helm_release" "kube-proxy" {
  chart            = "../helm-wrapper"
  name             = "kube-proxy"
  namespace        = "kube-system"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = module.kube-proxy.manifests
    }),
  ]
}

resource "helm_release" "flannel" {
  chart            = "../helm-wrapper"
  name             = "flannel"
  namespace        = "kube-system"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = module.flannel.manifests
    }),
  ]
}

# Kubelet CSR approver

resource "helm_release" "kubelet-csr-approver" {
  name             = "kubelet-csr-approver"
  namespace        = "kube-system"
  repository       = "https://postfinance.github.io/kubelet-csr-approver"
  chart            = "kubelet-csr-approver"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "1.2.13"
  max_history      = 2
  values = [
    yamlencode({
      global = {
        clusterDomain = local.domains.kubernetes
      }
      providerRegex       = "^k-\\d+$"
      bypassDnsResolution = true
      bypassHostnameCheck = true
      providerIpPrefixes = [
        local.networks.service.prefix,
      ]
      metrics = {
        enable = true
        port   = local.service_ports.metrics
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = tostring(local.service_ports.metrics)
        }
      }
    }),
  ]
}

# fluxCD

resource "helm_release" "flux2" {
  name             = "flux2"
  namespace        = "flux-system"
  repository       = "https://fluxcd-community.github.io/helm-charts"
  chart            = "flux2"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "2.18.2"
  max_history      = 2
  values = [
    yamlencode({
      clusterDomain = local.domains.kubernetes
      imageAutomationController = {
        create = false
      }
      imageReflectionController = {
        create = false
      }
      notificationController = {
        create = false
      }
    }),
  ]
}
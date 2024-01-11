locals {
  kubelet_access_role_name = "system:kube-apiserver-to-kubelet"

  # node bootstrap #

  # https://medium.com/@toddrosner/kubernetes-tls-bootstrapping-cf203776abc7
  # https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/08-bootstrapping-kubernetes-controllers.md
  node_bootstrap_rolebinding = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "kubelet-bootstrap"
      labels = {
        app     = var.name
        release = var.release
      }
    }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "system:node-bootstrapper"
    }
    subjects = [
      {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "User"
        name     = var.kube_node_bootstrap_user
      }
    ]
  }

  node_approver_rolebinding = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "node-client-auto-approve-csr"
      labels = {
        app     = var.name
        release = var.release
      }
    }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "system:certificates.k8s.io:certificatesigningrequests:nodeclient"
    }
    subjects = [
      {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "User"
        name     = var.kube_node_bootstrap_user
      }
    ]
  }

  node_renewal_rolebinding = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "auto-approve-renewals-for-nodes"
      labels = {
        app     = var.name
        release = var.release
      }
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
      }
    ]
  }

  # kube apiserver access to kubelet #

  # https://stackoverflow.com/questions/48118125/kubernetes-rbac-role-verbs-to-exec-to-pod
  kubelet_access_role = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRole"
    metadata = {
      name = local.kubelet_access_role_name
      annotations = {
        "rbac.authorization.kubernetes.io/autoupdate" = "true"
      }
      labels = {
        "kubernetes.io/bootstrapping" = "rbac-defaults"
        app                           = var.name
        release                       = var.release
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
      }
    ]
  }

  kubelet_access_rolebinding = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "system:kube-apiserver"
      labels = {
        app     = var.name
        release = var.release
      }
    }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = local.kubelet_access_role_name
    }
    subjects = [
      {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "User"
        name     = var.kube_kubelet_access_user
      }
    ]
  }
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = {
    "templates/node-bootstrap-rolebinding.yaml" = yamlencode(local.node_bootstrap_rolebinding)
    "templates/node-approver-rolebinding.yaml"  = yamlencode(local.node_approver_rolebinding)
    "templates/node-renewal-rolebinding.yaml"   = yamlencode(local.node_renewal_rolebinding)
    "templates/kubelet-access-role.yaml"        = yamlencode(local.kubelet_access_role)
    "templates/kubelet-access-rolebinding.yaml" = yamlencode(local.kubelet_access_rolebinding)
  }
}
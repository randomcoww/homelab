module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = {
    # https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/

    # enable bootstrapping nodes to create CSR
    "templates/create-csrs-for-bootstrapping-rolebinding.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "ClusterRoleBinding"
      metadata = {
        name = "create-csrs-for-bootstrapping"
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
          kind     = "Group"
          name     = "system:bootstrappers"
        },
      ]
    })

    # Approve all CSRs for the group "system:bootstrappers"
    "templates/auto-approve-csrs-for-group-rolebinding.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "ClusterRoleBinding"
      metadata = {
        name = "auto-approve-csrs-for-group"
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
          kind     = "Group"
          name     = "system:bootstrappers"
        },
      ]
    })

    # Approve renewal CSRs for the group "system:nodes"
    "templates/auto-approve-renewals-for-nodes-rolebinding.yaml" = yamlencode({
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
        },
      ]
    })

    # kube apiserver access to kubelet #

    # https://stackoverflow.com/questions/48118125/kubernetes-rbac-role-verbs-to-exec-to-pod
    "templates/kubelet-access-role.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "ClusterRole"
      metadata = {
        name = "system:kube-apiserver-to-kubelet"
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
        },
      ]
    })

    "templates/kubelet-access-rolebinding.yaml" = yamlencode({
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
        name     = "system:kube-apiserver-to-kubelet"
      }
      subjects = [
        {
          apiGroup = "rbac.authorization.k8s.io"
          kind     = "User"
          name     = var.kubelet_client_user
        },
      ]
    })
  }
}
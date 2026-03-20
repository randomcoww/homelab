output "manifests" {
  value = concat([
    for _, m in [
      {
        apiVersion = "v1"
        kind       = "ServiceAccount"
        metadata = {
          name = var.name
          labels = {
            app = var.name
          }
        }
      },
      {
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind       = "ClusterRole"
        metadata = {
          name = var.name
          labels = {
            app = var.name
          }
        }
        rules = [
          {
            apiGroups = [""]
            resources = ["pods"]
            verbs     = ["get"]
          },
          {
            apiGroups = [""]
            resources = ["nodes"]
            verbs     = ["list", "watch"]
          },
          {
            apiGroups = [""]
            resources = ["nodes/status"]
            verbs     = ["patch"]
          },
        ]
      },
      {
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind       = "ClusterRoleBinding"
        metadata = {
          name = var.name
          labels = {
            app = var.name
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
    ] :
    yamlencode(m)
    ], [
    module.configmap.manifest,
    module.daemonset.manifest,
  ])
}
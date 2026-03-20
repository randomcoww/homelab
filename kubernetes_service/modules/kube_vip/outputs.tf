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
          annotations = {
            "rbac.authorization.kubernetes.io/autoupdate" = "true"
          }
        }
        rules = [
          {
            apiGroups = [""]
            resources = ["services/status"]
            verbs     = ["update"]
          },
          {
            apiGroups = [""]
            resources = ["services", "endpoints"]
            verbs     = ["list", "get", "watch", "update"]
          },
          {
            apiGroups = [""]
            resources = ["nodes"]
            verbs     = ["list", "get", "watch", "update", "patch"]
          },
          {
            apiGroups = ["coordination.k8s.io"]
            resources = ["leases"]
            verbs     = ["list", "get", "watch", "update", "create"]
          },
          {
            apiGroups = ["discovery.k8s.io"]
            resources = ["endpointslices"]
            verbs     = ["list", "get", "watch", "update"]
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
      },
    ] :
    yamlencode(m)
    ], [
    module.daemonset.manifest,
  ])
}
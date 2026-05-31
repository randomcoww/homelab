output "manifests" {
  value = concat([
    module.deployment.manifest,
    module.secret.manifest,
    module.service.manifest,
    module.httproute.manifest,
    ], [
    for _, m in [
      # kubernetes-mcp
      {
        apiVersion = "v1"
        kind       = "ServiceAccount"
        metadata = {
          name      = var.name
          namespace = var.namespace
          labels = {
            app     = var.name
            release = var.release
          }
        }
      },
      {
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
      },
      {
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
      },
    ] :
    yamlencode(m)
  ])
}
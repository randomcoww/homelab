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
        kind       = "ClusterRoleBinding"
        metadata = {
          name = "system:kube-proxy"
          labels = {
            app = var.name
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
      },
    ] :
    yamlencode(m)
    ], [
    module.daemonset.manifest,
  ])
}
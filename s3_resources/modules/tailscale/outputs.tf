output "manifests" {
  value = concat([
    module.secret.manifest,
    module.statefulset.manifest,
    ], [
    for _, m in [
      {
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind       = "Role"
        metadata = {
          name      = var.name
          namespace = var.namespace
          labels = {
            app     = var.name
            release = var.release
          }
        }
        rules = [
          {
            apiGroups = [""]
            resources = ["secrets"]
            verbs     = ["create"]
          },
          {
            apiGroups = [""]
            resourceNames = [
              for i, _ in range(var.replicas) :
              "${var.name}-${i}"
            ]
            resources = ["secrets"]
            verbs     = ["get", "update", "patch"]
          },
        ]
      },
      {
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind       = "RoleBinding"
        metadata = {
          name      = var.name
          namespace = var.namespace
          labels = {
            app     = var.name
            release = var.release
          }
        }
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io"
          kind     = "Role"
          name     = var.name
        }
        subjects = [
          {
            kind = "ServiceAccount"
            name = var.name
          },
        ]
      },
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
    ] :
    yamlencode(m)
  ])
}
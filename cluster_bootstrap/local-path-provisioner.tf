resource "helm_release" "local-path-provisioner" {
  chart            = "local-path-provisioner"
  name             = "local-path-provisioner"
  namespace        = "kube-system"
  repository       = "https://charts.containeroo.ch"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "0.0.38"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      replicaCount = 2
      storageClass = {
        create            = true
        name              = "local-path"
        provisionerName   = "rancher.io/local-path"
        defaultClass      = true
        defaultVolumeType = "local"
      }
      nodePathMap = [
        {
          node = "DEFAULT_PATH_FOR_NON_LISTED_NODES"
          paths = [
            "${local.kubernetes.containers_path}/local_path_provisioner",
          ]
        },
      ]
      resources = {
        requests = {
          memory = "128Mi"
        }
        limits = {
          memory = "128Mi"
        }
      }
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}
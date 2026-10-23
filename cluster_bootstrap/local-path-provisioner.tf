module "local-path-provisioner" {
  source       = "./modules/local-path-provisioner"
  name         = "local-path-provisioner"
  namespace    = "kube-system"
  replicas     = 2
  timeout      = local.kubernetes.helm_release_timeout
  volume_paths = [local.kubernetes.local_path_provisioner_path]

  depends_on = [
    kubernetes_node_taint.taints,
  ]
}
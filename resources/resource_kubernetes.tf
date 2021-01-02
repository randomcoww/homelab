# https://github.com/hashicorp/terraform-provider-kubernetes-alpha

resource "null_resource" "kubernetes_resources" {
  triggers = merge(
    local.kubernetes_namespaces,
    local.kubernetes_manifests
  )
}

# Ignore duplicate manifests if name, namespace and kind are same
module "kubernetes-namespaces" {
  source = "../modules/kubernetes"

  kubernetes_manifests = local.kubernetes_namespaces
  cluster_endpoint = module.template-kubernetes.cluster_endpoint
}

module "kubernetes-addons" {
  source = "../modules/kubernetes"

  kubernetes_manifests = local.kubernetes_manifests
  cluster_endpoint = module.template-kubernetes.cluster_endpoint
}
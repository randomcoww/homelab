locals {
  kubernetes_manifests = compact([
    lookup(module.template-ingress, "kubernetes", ""),
    lookup(module.template-secrets, "kubernetes", ""),
    lookup(module.template-kubernetes, "kubernetes", ""),
  ])
}

# https://github.com/hashicorp/terraform-provider-kubernetes-alpha
module "kubernetes-addons" {
  source = "../modules/kubernetes"

  kubernetes_manifests = local.kubernetes_manifests
  cluster_endpoint     = module.template-kubernetes.cluster_endpoint
}
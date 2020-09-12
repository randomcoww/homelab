# https://github.com/hashicorp/terraform-provider-kubernetes-alpha
module "kubernetes-addons" {
  source = "../modulesv2/kubernetes_addons"

  kubernetes_manifests = merge(
    module.secrets.addons,
    module.tls-secrets.addons
  )
  cluster_endpoint = module.kubernetes-common.cluster_endpoint
}
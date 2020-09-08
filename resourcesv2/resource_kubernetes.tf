# https://github.com/hashicorp/terraform-provider-kubernetes-alpha
module "kubernetes-addons" {
  source = "../modulesv2/kubernetes_addons"

  kubernetes_manifests = data.null_data_source.provider-addons.outputs
  cluster_endpoint     = module.kubernetes-common.cluster_endpoint
}
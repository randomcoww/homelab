# intermediate manifests to force dependencies to run
data "null_data_source" "kubernetes-manifests" {
  inputs = merge(
    module.secrets.addons,
    module.tls-secrets.addons
  )
}

# https://github.com/hashicorp/terraform-provider-kubernetes-alpha
module "kubernetes-addons" {
  source = "../modulesv2/kubernetes_addons"

  kubernetes_manifests = data.null_data_source.kubernetes-manifests.outputs
  cluster_endpoint = module.kubernetes-common.cluster_endpoint
}
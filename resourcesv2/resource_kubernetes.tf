# intermediate manifests to force dependencies to run
data "null_data_source" "kubernetes-manifests" {
  inputs = merge(
    module.tls-secrets.addons,
    module.secrets.addons,
    module.kubernetes-common.addons,
  )
}

# https://github.com/hashicorp/terraform-provider-kubernetes-alpha
module "kubernetes-addons" {
  source = "../modulesv2/kubernetes_addons"

  kubernetes_manifests = values(data.null_data_source.kubernetes-manifests.outputs)
  cluster_endpoint = module.kubernetes-common.cluster_endpoint
}
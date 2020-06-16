# https://github.com/hashicorp/terraform-provider-kubernetes-alpha
module "kubernetes-addons" {
  source = "../modulesv2/kubernetes_addons"

  cluster_endpoint = module.kubernetes-common.cluster_endpoint
  kubernetes_manifests = merge(
    # module.gateway-common.addons,
    # module.kubernetes-common.addons,
    module.secrets.addons,
    module.tls-secrets.addons,
    # module.ssh-common.addons,
    # module.static-pod-logging.addons,
    # module.test-common.addons,
  )
}
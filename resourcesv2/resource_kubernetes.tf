# intermediate manifests to force dependencies to run
data "null_data_source" "kubernetes-manifests" {
  inputs = merge(
    module.tls-secrets.addons,
    module.secrets.addons,
    module.kubernetes-common.addons,
  )
}

module "kubernetes-namespaces" {
  source = "../modulesv2/kubernetes_addons"

  kubernetes_manifests = [
    for k in [
      "common",
      "monitoring",
      "minio",
      "metallb-system"
    ] : <<-EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${k}
EOF
  ]
  cluster_endpoint = module.kubernetes-common.cluster_endpoint
}

# https://github.com/hashicorp/terraform-provider-kubernetes-alpha
module "kubernetes-addons" {
  source = "../modulesv2/kubernetes_addons"

  kubernetes_manifests = values(data.null_data_source.kubernetes-manifests.outputs)
  cluster_endpoint     = module.kubernetes-common.cluster_endpoint
}
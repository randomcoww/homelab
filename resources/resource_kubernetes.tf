# https://github.com/hashicorp/terraform-provider-kubernetes-alpha
module "kubernetes-namespaces" {
  source = "../modules/kubernetes"

  kubernetes_manifests = {
    for j in local.kubernetes_addons :
    "${j.kind}-${lookup(j.metadata, "namespace", "default")}-${j.metadata.name}" => yamlencode(j)
    if lookup(j, "kind", null) == "Namespace"
  }
  cluster_endpoint = module.template-kubernetes.cluster_endpoint
}

module "kubernetes-addons" {
  source = "../modules/kubernetes"

  kubernetes_manifests = {
    for j in local.kubernetes_addons :
    "${j.kind}-${lookup(j.metadata, "namespace", "default")}-${j.metadata.name}" => yamlencode(j)
    if lookup(j, "kind", "Namespace") != "Namespace"
  }
  cluster_endpoint = module.template-kubernetes.cluster_endpoint
}
# https://github.com/hashicorp/terraform-provider-kubernetes-alpha

# Ignore duplicate manifests if name, namespace and kind are same
module "kubernetes-namespaces" {
  source = "../modules/kubernetes"

  kubernetes_manifests = {
    for k, v in {
      for j in local.kubernetes_addons :
      "${j.kind}-${lookup(j.metadata, "namespace", "default")}-${j.metadata.name}" => [yamlencode(j)]...
      if lookup(j, "kind", null) == "Namespace"
    } :
    k => flatten(v)[0]
  }
  cluster_endpoint = module.template-kubernetes.cluster_endpoint
}

module "kubernetes-addons" {
  source = "../modules/kubernetes"

  kubernetes_manifests = {
    for k, v in {
      for j in local.kubernetes_addons :
      "${j.kind}-${lookup(j.metadata, "namespace", "default")}-${j.metadata.name}" => [yamlencode(j)]...
      if lookup(j, "kind", "Namespace") != "Namespace"
    } :
    k => flatten(v)[0]
  }
  cluster_endpoint = module.template-kubernetes.cluster_endpoint
}
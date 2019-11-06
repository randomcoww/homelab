module "kubernetes-addons" {
  source = "../modulesv2/addons"

  namespace        = "kube-system"
  networks         = local.networks
  services         = local.services
  domains          = local.domains
  container_images = local.container_images

  renderer = local.renderer_local
}
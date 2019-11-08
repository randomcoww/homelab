module "kubernetes-addons" {
  source = "../modulesv2/addons"

  namespace        = "kube-system"
  networks         = local.networks
  services         = local.services
  domains          = local.domains
  container_images = local.container_images

  # Render to one of KVM host matchbox instances
  # renderer = local.renderers[var.renderer]
  renderer = local.local_renderer
}
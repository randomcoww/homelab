module "kubernetes-addons" {
  source = "../modulesv2/kubernetes_addons"

  namespace        = "kube-system"
  networks         = local.networks
  services         = local.services
  domains          = local.domains
  container_images = local.container_images

  internal_cert_pem        = tls_locally_signed_cert.internal.cert_pem
  internal_private_key_pem = tls_private_key.internal.private_key_pem

  # Render to one of KVM host matchbox instances
  # renderer = local.renderers[var.renderer]
  renderer = local.local_renderer
}
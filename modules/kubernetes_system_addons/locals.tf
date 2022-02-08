locals {
  addon_manifests = {
    for f in fileset(".", "${path.module}/manifests/*.yaml") :
    basename(f) => templatefile(f, merge(var.template_params, {
      flannel_host_gateway_interface_name = var.flannel_host_gateway_interface_name
      internal_domain                     = var.internal_domain
      internal_domain_dns_ip              = var.internal_domain_dns_ip
      forwarding_dns_ip                   = var.forwarding_dns_ip
      metallb_network_prefix              = var.metallb_network_prefix
      metallb_network_prefix              = var.metallb_network_prefix
      container_images                    = var.container_images
    }))
  }
}
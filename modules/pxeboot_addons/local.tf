locals {
  matchbox_certs = {
    ca   = tls_self_signed_cert.matchbox-ca.cert_pem
    cert = tls_locally_signed_cert.matchbox.cert_pem
    key  = tls_private_key.matchbox.private_key_pem
  }

  addon_manifests = {
    for f in fileset(".", "${path.module}/manifests/*.yaml") :
    basename(f) => templatefile(f, {
      container_images           = var.container_images
      resource_name              = var.resource_name
      affinity_resource_name     = var.affinity_resource_name
      namespace                  = var.resource_namespace
      replica_count              = var.replica_count
      matchbox_certs             = local.matchbox_certs
      matchbox_path              = var.matchbox_path
      internal_pxeboot_ip        = var.internal_pxeboot_ip
      internal_pxeboot_api_port  = var.internal_pxeboot_api_port
      internal_pxeboot_http_port = var.internal_pxeboot_http_port
    })
  }
}

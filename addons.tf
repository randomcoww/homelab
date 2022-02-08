# basic system #
module "kubernetes-system-addons" {
  source                 = "./modules/kubernetes_system_addons"
  template_params        = module.kubernetes-common.template_params
  internal_domain        = local.domains.internal
  internal_domain_dns_ip = local.networks.metallb.vips.external_dns
  forwarding_dns_ip      = local.networks.lan.vips.forwarding_dns
  metallb_network_prefix = local.networks.metallb.prefix
  container_images       = local.container_images
}

data "http" "remote-kubernetes-addons" {
  for_each = {
    "nvidia-device-plugins.yaml" = "https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.10.0/nvidia-device-plugin.yml"
    "metallb-namespace.yaml"     = "https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/namespace.yaml"
    "metallb.yaml"               = "https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml"
  }
  url = each.value
}


# pxeboot #
module "pxeboot-addons" {
  source                     = "./modules/pxeboot_addons"
  resource_name              = "pxeboot"
  resource_namespace         = "default"
  replica_count              = 2
  internal_pxeboot_ip        = local.networks.metallb.vips.internal_pxeboot
  internal_pxeboot_http_port = local.ports.internal_pxeboot_http
  internal_pxeboot_api_port  = local.ports.internal_pxeboot_api
  container_images           = local.container_images
}

resource "tls_private_key" "matchbox-client" {
  algorithm   = module.pxeboot-addons.ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "matchbox-client" {
  key_algorithm   = tls_private_key.matchbox-client.algorithm
  private_key_pem = tls_private_key.matchbox-client.private_key_pem

  subject {
    common_name  = "matchbox"
    organization = "matchbox"
  }

  ip_addresses = [
    local.networks.metallb.vips.internal_pxeboot,
  ]
}

resource "tls_locally_signed_cert" "matchbox-client" {
  cert_request_pem   = tls_cert_request.matchbox-client.cert_request_pem
  ca_key_algorithm   = module.pxeboot-addons.ca.algorithm
  ca_private_key_pem = module.pxeboot-addons.ca.private_key_pem
  ca_cert_pem        = module.pxeboot-addons.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

resource "local_file" "pxeboot_certs" {
  for_each = {
    "matchbox-ca.pem"   = module.pxeboot-addons.ca.cert_pem
    "matchbox-cert.pem" = tls_locally_signed_cert.matchbox-client.cert_pem
    "matchbox-key.pem"  = tls_private_key.matchbox-client.private_key_pem
  }

  filename = "./output/certs/${each.key}"
  content  = each.value
}


# minio addon for aio-0 host #
module "minio-addons" {
  source             = "./modules/minio_addons"
  resource_name      = "minio"
  resource_namespace = "default"
  replica_count      = 1
  minio_ip           = local.networks.metallb.vips.minio
  minio_port         = local.ports.minio
  minio_console_port = local.ports.minio_console
  node_selector      = { "host_key" = "aio-0" }
  volume_paths       = local.hosts.aio-0.minio_volume_paths
  container_images   = local.container_images
}

output "minio_endpoint" {
  value = module.minio-addons.endpoint
}
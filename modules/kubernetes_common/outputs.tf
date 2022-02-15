output "ca" {
  value = local.ca
}

output "certs" {
  value = local.certs
}

output "template_params" {
  value = {
    cluster_name              = var.cluster_name
    pod_network               = local.pod_network
    service_network           = local.service_network
    cni_bridge_interface_name = local.cni_bridge_interface_name
    apiserver_vip             = var.apiserver_vip
    apiserver_port            = var.apiserver_port
    etcd_cluster_endpoints    = var.etcd_cluster_endpoints
    cluster_domain            = var.cluster_domain
    encryption_config_secret  = base64encode(chomp(random_string.encryption-config-secret.result))
    addons_resource_whitelist = local.addons_resource_whitelist
  }
}
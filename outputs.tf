output "ssh_client_cert_authorized_key" {
  value = ssh_client_cert.ssh-client.cert_authorized_key
}

output "kubeconfig_admin" {
  value = nonsensitive(templatefile("./templates/kubeconfig_admin.yaml", {
    cluster_name       = local.config.kubernetes_cluster_name
    ca_pem             = module.kubernetes-common.admin.ca_pem
    private_key_pem    = module.kubernetes-common.admin.private_key_pem
    cert_pem           = module.kubernetes-common.admin.cert_pem
    apiserver_endpoint = "https://${cidrhost(local.config.networks.lan.prefix, local.aio_hostclass_config.vrrp_netnum)}:${local.config.ports.apiserver}"
  }))
}
resource "null_resource" "output" {
  triggers = merge({
    for k, v in module.template-ssh.client_params :
    "ssh-${k}" => v
    }, {
    for k, v in module.template-kubernetes.cluster_endpoint :
    "kubernetes-${k}" => v
  })
}

# Minio UI access
output "minio-auth" {
  value = {
    access_key_id     = random_password.minio-user.result
    secret_access_key = random_password.minio-password.result
  }
}

# Grafana auth
output "grafana-auth" {
  value = {
    user     = random_password.grafana-user.result
    password = random_password.grafana-password.result
  }
}

# Add to ~/.ssh/known_hosts @cert-authority * <key>
output "ssh-ca-authorized-key" {
  value = module.template-ssh.client_params.ssh_ca_authorized_key
}

# Signed client public key for ~/.ssh/id_ecdsa-cert.pub
output "ssh-client-certificate" {
  value = module.template-ssh.client_params.ssh_client_certificate
}

output "kubeconfig" {
  value = templatefile("./templates/kubeconfig_admin.yaml", {
    cluster_name       = module.template-kubernetes.cluster_endpoint.cluster_name
    ca_pem             = module.template-kubernetes.cluster_endpoint.kubernetes_ca_pem
    cert_pem           = module.template-kubernetes.cluster_endpoint.kubernetes_cert_pem
    private_key_pem    = module.template-kubernetes.cluster_endpoint.kubernetes_private_key_pem
    apiserver_endpoint = module.template-kubernetes.cluster_endpoint.apiserver_endpoint
  })
}
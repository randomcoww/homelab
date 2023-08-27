locals {
  certs = {
    ca_cert = {
      content = var.ca.cert_pem
    }
    cert = {
      content = tls_locally_signed_cert.admin.cert_pem
    }
    key = {
      content = tls_private_key.admin.private_key_pem
    }
  }

  kubeconfig = templatefile("${path.module}/manifests/kubeconfig_admin.yaml", {
    cluster_name       = var.cluster_name
    certs              = local.certs
    apiserver_endpoint = var.apiserver_endpoint
  })
}
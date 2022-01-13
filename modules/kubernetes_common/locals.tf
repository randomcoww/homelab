locals {
  certs = {
    kubernetes = {
      ca_cert = {
        content = tls_self_signed_cert.kubernetes-ca.cert_pem
      }
      ca_key = {
        content = tls_private_key.kubernetes-ca.private_key_pem
      }
      controller_manager_cert = {
        content = tls_locally_signed_cert.controller-manager.cert_pem
      }
      controller_manager_key = {
        content = tls_private_key.controller-manager.private_key_pem
      }
      scheduler_cert = {
        content = tls_locally_signed_cert.scheduler.cert_pem
      }
      scheduler_key = {
        content = tls_private_key.scheduler.private_key_pem
      }
      kubelet_cert = {
        content = tls_locally_signed_cert.kubelet.cert_pem
      }
      kubelet_key = {
        content = tls_private_key.kubelet.private_key_pem
      }
      service_account_cert = {
        content = tls_private_key.service-account.public_key_pem
      }
      service_account_key = {
        content = tls_private_key.service-account.private_key_pem
      }
    }
    etcd = {
      ca_cert = {
        content = tls_self_signed_cert.etcd-ca.cert_pem
      }
      client_cert = {
        content = tls_locally_signed_cert.etcd-client.cert_pem
      }
      client_key = {
        content = tls_private_key.etcd-client.private_key_pem
      }
    }
  }
}

resource "random_string" "encryption-config-secret" {
  length  = 32
  special = false
}
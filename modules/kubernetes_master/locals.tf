locals {
  certs_path = "/var/lib/kubernetes/pki"

  certs = {
    for cert_name, cert in merge(var.certs, {
      apiserver_cert = {
        content = tls_locally_signed_cert.apiserver.cert_pem
      }
      apiserver_key = {
        content = tls_private_key.apiserver.private_key_pem
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
    }) :
    cert_name => merge(cert, {
      path = "${local.certs_path}/kubbernetes-${cert_name}.pem"
    })
  }

  etcd_certs = {
    for cert_name, cert in merge(var.etcd_certs, {
      client_cert = {
        content = tls_locally_signed_cert.etcd-client.cert_pem
      }
      client_key = {
        content = tls_private_key.etcd-client.private_key_pem
      }
    }) :
    cert_name => merge(cert, {
      path = "${local.certs_path}/etcd-${cert_name}.pem"
    })
  }

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      config_path              = "/var/lib/kubernetes/config"
      cluster_name             = var.cluster_name
      certs                    = local.certs
      etcd_certs               = local.etcd_certs
      certs_path               = local.certs_path
      static_pod_manifest_path = var.static_pod_manifest_path
      service_network          = var.service_network
      pod_network              = var.pod_network
      etcd_cluster_endpoints   = var.etcd_cluster_endpoints
      encryption_config_secret = var.encryption_config_secret
      container_images         = var.container_images
      apiserver_port           = var.apiserver_port
      apiserver_internal_port  = var.apiserver_internal_port
      controller_manager_port  = var.controller_manager_port
      scheduler_port           = var.scheduler_port
      apiserver_members        = var.apiserver_members
      nginx_config_path        = var.nginx_config_path
    })
  ]
}
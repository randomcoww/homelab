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
      addons_manager_cert = {
        content = tls_locally_signed_cert.addons-manager.cert_pem
      }
      addons_manager_key = {
        content = tls_private_key.addons-manager.private_key_pem
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
    templatefile(f, merge(var.template_params, {
      static_pod_manifest_path = var.static_pod_manifest_path
      addon_manifests_path     = var.addon_manifests_path
      config_path              = "/var/lib/kubernetes/config"
      certs_path               = local.certs_path
      certs                    = local.certs
      etcd_certs               = local.etcd_certs
    }))
  ]
}
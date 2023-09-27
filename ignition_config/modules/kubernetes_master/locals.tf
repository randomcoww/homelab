locals {
  pki_path = "/var/lib/kubernetes/pki"

  pki = {
    for cert_name, cert in {
      ca_cert = {
        content = var.ca.cert_pem
      }
      ca_key = {
        content = var.ca.private_key_pem
      }
      service_account_cert = {
        content = var.service_account.public_key_pem
      }
      service_account_key = {
        content = var.service_account.private_key_pem
      }
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
    } :
    cert_name => merge(cert, {
      path = "${local.pki_path}/kubernetes-${cert_name}.pem"
    })
  }

  etcd_pki = {
    for cert_name, cert in {
      ca_cert = {
        content = var.etcd_ca.cert_pem
      }
      client_cert = {
        content = tls_locally_signed_cert.etcd-client.cert_pem
      }
      client_key = {
        content = tls_private_key.etcd-client.private_key_pem
      }
    } :
    cert_name => merge(cert, {
      path = "${local.pki_path}/etcd-${cert_name}.pem"
    })
  }

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      container_images          = var.container_images
      cluster_name              = var.cluster_name
      pki_path                  = local.pki_path
      pki                       = local.pki
      etcd_pki                  = local.etcd_pki
      kubernetes_service_prefix = var.kubernetes_service_prefix
      kubernetes_pod_prefix     = var.kubernetes_pod_prefix
      etcd_cluster_endpoints = join(",", [
        for _, ip in var.etcd_cluster_members :
        "https://${ip}:${var.etcd_client_port}"
      ])
      apiserver_vip            = var.apiserver_vip
      cluster_members          = var.cluster_members
      apiserver_port           = var.apiserver_port
      apiserver_ha_port        = var.apiserver_ha_port
      controller_manager_port  = var.controller_manager_port
      scheduler_port           = var.scheduler_port
      sync_interface_name      = var.sync_interface_name
      apiserver_interface_name = var.apiserver_interface_name

      static_pod_manifest_path = var.static_pod_manifest_path
      config_path              = "/var/lib/kubernetes/config"
      haproxy_config_path      = var.haproxy_config_path
      keepalived_config_path   = var.keepalived_config_path
      virtual_router_id        = 11
    })
  ]
}
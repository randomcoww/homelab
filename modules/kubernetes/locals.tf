locals {
  # assign names for guest interfaces by order
  # libvirt assigns names ens2, ens3 ... ensN in order defined in domain XML
  tap_interfaces = {
    for network_name, tap_interface in var.tap_interfaces :
    network_name => merge(var.networks[network_name], tap_interface, {
      interface_name      = network_name
      vmac_interface_name = "${network_name}-vmac"
    })
  }

  certs = {
    kubernetes = {
      ca_cert = {
        path    = "${var.controller_config_path}/ca.pem"
        content = tls_self_signed_cert.ca.cert_pem
      }
      ca_key = {
        path    = "${var.controller_config_path}/ca_key.pem"
        content = tls_private_key.ca.private_key_pem
      }
      cluster_cert = {
        path    = "${var.controller_config_path}/cluster.pem"
        content = tls_locally_signed_cert.apiserver.cert_pem
      }
      cluster_key = {
        path    = "${var.controller_config_path}/cluster_key.pem"
        content = tls_private_key.apiserver.private_key_pem
      }
      controller_manager_cert = {
        path    = "${var.controller_config_path}/controller_manager.pem"
        content = tls_locally_signed_cert.controller-manager.cert_pem
      }
      controller_manager_key = {
        content = tls_private_key.controller-manager.private_key_pem
        path    = "${var.controller_config_path}/controller_manager_key.pem"
      }
      scheduler_cert = {
        content = tls_locally_signed_cert.scheduler.cert_pem
        path    = "${var.controller_config_path}/scheduler.pem"
      }
      scheduler_key = {
        content = tls_private_key.scheduler.private_key_pem
        path    = "${var.controller_config_path}/scheduler_key.pem"
      }
      kubelet_cert = {
        content = tls_locally_signed_cert.kubelet.cert_pem
        path    = "${var.controller_config_path}/kubelet.pem"
      }
      kubelet_key = {
        content = tls_private_key.kubelet.private_key_pem
        path    = "${var.controller_config_path}/kubelet_key.pem"
      }
      service_account_cert = {
        content = tls_private_key.service-account.public_key_pem
        path    = "${var.controller_config_path}/service_account.pem"
      }
      service_account_key = {
        content = tls_private_key.service-account.private_key_pem
        path    = "${var.controller_config_path}/service_account_key.pem"
      }
    }
    elcd = {
      ca_cert = {
        content = var.etcd_ca.cert_pem
        path    = "${var.controller_config_path}/etcd-ca-cert.pem"
      }
      client_cert = {
        content = tls_locally_signed_cert.etcd-client.cert_pem
        path    = "${var.controller_config_path}/etcd-client-cert.pem"
      }
      client_key = {
        content = tls_private_key.etcd-client.private_key_pem
        path    = "${var.controller_config_path}/etcd-client-key.pem"
      }
    }
  }

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      container_images = var.container_images
      certs            = local.certs

      # controller #
      kubernetes_service_network = var.kubernetes_service_network
      kubernetes_network         = var.kubernetes_service_network
      etcd_cluster_ip            = var.etcd_cluster_ip
      etcd_client_port           = var.ports.etcd_client
      apiserver_ip               = "127.0.0.1"
      apiserver_port             = var.ports.apiserver
      encryption_config_secret   = var.encryption_config_secret
      controller_config_path     = "/var/lib/kubelet/config"
      static_pod_manifest_path   = "/var/lib/kubelet/manifests"
      static_pod_config_path     = "/var/lib/kubelet/podconfig"

      # kubelet #
      kubernetes_dns_netnum = 10
      kubelet_config_path   = "/var/lib/kubelet/config"
      kubelet_node_ip       = var.kubelet_node_ip
      kubelet_node_labels   = var.kubelet_node_labels
    })
  ]
}
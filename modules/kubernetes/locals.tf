locals {
  certs_path = "/var/lib/kubernetes/pki"

  certs = {
    kubernetes = {
      for cert_name, cert in merge(var.kubernetes_common_certs, {
        apiserver_cert = {
          content = tls_locally_signed_cert.apiserver.cert_pem
        }
        apiserver_key = {
          content = tls_private_key.apiserver.private_key_pem
        }
      }) :
      cert_name => merge(cert, {
        path = "${local.certs_path}/kubernetes-${cert_name}.pem"
      })
    }
    addons_manager = {
      for cert_name, cert in merge(var.kubernetes_common_certs, {
        cert = {
          content = tls_locally_signed_cert.addons-manager.cert_pem
        }
        key = {
          content = tls_private_key.addons-manager.private_key_pem
        }
      }) :
      cert_name => merge(cert, {
        path = "${local.certs_path}/addons-manager-${cert_name}.pem"
      })
    }
    etcd = {
      for cert_name, cert in var.etcd_common_certs :
      cert_name => merge(cert, {
        path = "${local.certs_path}/etcd-${cert_name}.pem"
      })
    }
  }

  addons_resource_whitelist = [
    "core/v1/ConfigMap",
    "core/v1/Endpoints",
    "core/v1/Namespace",
    "core/v1/PersistentVolumeClaim",
    "core/v1/PersistentVolume",
    "core/v1/Pod",
    "core/v1/ReplicationController",
    "core/v1/Secret",
    "core/v1/Service",
    "batch/v1/Job",
    "batch/v1/CronJob",
    "apps/v1/DaemonSet",
    "apps/v1/Deployment",
    "apps/v1/ReplicaSet",
    "apps/v1/StatefulSet",
    "networking.k8s.io/v1/IngressClass",
    "networking.k8s.io/v1/NetworkPolicy",
    "apiextensions.k8s.io/v1/CustomResourceDefinition",
  ]

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      container_images = var.container_images
      kubernetes_certs = local.certs.kubernetes
      etcd_certs       = local.certs.etcd
      network_prefix   = var.network_prefix
      host_netnum      = var.host_netnum
      vip_netnum       = var.vip_netnum
      config_path      = "/var/lib/kubernetes/config"

      # controller #
      cluster_name                      = var.kubernetes_cluster_name
      kubernetes_service_network_prefix = var.kubernetes_service_network_prefix
      kubernetes_pod_network_prefix     = var.kubernetes_pod_network_prefix
      etcd_servers                      = var.etcd_servers
      etcd_client_port                  = var.etcd_client_port
      apiserver_ip                      = "127.0.0.1"
      apiserver_port                    = var.apiserver_port
      controller_manager_port           = var.controller_manager_port
      scheduler_port                    = var.scheduler_port
      encryption_config_secret          = var.encryption_config_secret
      static_pod_manifest_path          = var.static_pod_manifest_path
      certs_path                        = local.certs_path

      # addon manager #
      addons_resource_whitelist = local.addons_resource_whitelist
      addons_manager_certs      = local.certs.addons_manager
      addon_manifests_path      = var.addon_manifests_path
    })
  ]
}
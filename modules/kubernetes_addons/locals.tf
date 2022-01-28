locals {
  certs_path = "/var/lib/kubernetes/pki"

  certs = {
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
  ]

  addon_manifests = {
    for f in fileset(".", "${path.module}/manifests/*.yaml") :
    basename(f) => templatefile(f, {
      container_images                      = var.container_images
      flannel_host_gateway_interface_name   = var.flannel_host_gateway_interface_name
      kubernetes_pod_network_prefix         = var.kubernetes_pod_network_prefix
      kubernetes_service_network_prefix     = var.kubernetes_service_network_prefix
      kubernetes_service_network_dns_netnum = var.kubernetes_service_network_dns_netnum
      kubernetes_cluster_domain             = var.kubernetes_cluster_domain
    })
  }

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      static_pod_manifest_path  = var.static_pod_manifest_path
      config_path               = "/var/lib/kubernetes/config"
      kubernetes_addons_path    = "/var/lib/kubernetes/addons"
      cluster_name              = var.kubernetes_cluster_name
      apiserver_ip              = var.apiserver_ip
      apiserver_port            = var.apiserver_port
      container_images          = var.container_images
      addons_manager_certs      = local.certs.addons_manager
      addon_manifests           = local.addon_manifests
      certs_path                = local.certs_path
      addons_resource_whitelist = local.addons_resource_whitelist
    })
  ]
}
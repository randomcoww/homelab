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
    "networking.k8s.io/v1/IngressClass",
    "networking.k8s.io/v1/NetworkPolicy",
    "apiextensions.k8s.io/v1/CustomResourceDefinition",
  ]

  remote_manifests = {
    "nvidia-device-plugins.yaml" = "https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.10.0/nvidia-device-plugin.yml"
    "metallb-namespace.yaml"     = "https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/namespace.yaml"
    "metallb.yaml"               = "https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml"
  }

  addon_manifests = merge({
    for f in fileset(".", "${path.module}/manifests/*.yaml") :
    basename(f) => templatefile(f, {
      container_images                      = var.container_images
      flannel_host_gateway_interface_name   = var.flannel_host_gateway_interface_name
      kubernetes_pod_network_prefix         = var.kubernetes_pod_network_prefix
      kubernetes_service_network_prefix     = var.kubernetes_service_network_prefix
      kubernetes_service_network_dns_netnum = var.kubernetes_service_network_dns_netnum
      kubernetes_cluster_domain             = var.kubernetes_cluster_domain
      internal_domain                       = var.internal_domain
      internal_dns_ip                       = var.internal_dns_ip
      kubernetes_external_dns_ip            = var.kubernetes_external_dns_ip
      metallb_network_prefix                = var.metallb_network_prefix
      metallb_subnet                        = var.metallb_subnet
      apiserver_ip                          = var.apiserver_ip
      apiserver_port                        = var.apiserver_port
    })
    }, {
    for file_name in keys(local.remote_manifests) :
    file_name => data.http.remote-manifests[file_name].body
    }
  )

  addon_manifests_hcl = {
    for file_name, manifests in local.addon_manifests :
    file_name => [
      for resource in compact(flatten(regexall("(?ms)(.*?)^---", "${manifests}\n---"))) :
      yamldecode(resource)
    ]
  }

  # force inject addonmanager.kubernetes.io/mode label
  modified_addon_manifests = {
    for file_name, manifests in local.addon_manifests_hcl :
    file_name => join("---\n", [
      for manifest in manifests :
      yamlencode(merge(manifest, {
        metadata = merge(manifest.metadata, {
          labels = merge(lookup(manifest.metadata, "labels", {}), {
            "addonmanager.kubernetes.io/mode" : "EnsureExists"
        }) })
      }))
      if can(manifest.metadata)
    ])
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
      addon_manifests           = local.modified_addon_manifests
      certs_path                = local.certs_path
      addons_resource_whitelist = local.addons_resource_whitelist
    })
  ]
}
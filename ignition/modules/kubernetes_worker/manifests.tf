locals {
  config_path = "${var.config_base_path}/${var.name}"
  crio_socket = "/run/crio/crio.sock"

  pki = {
    for key, f in {
      ca-cert = {
        contents = var.kubernetes_ca.cert_pem
      }
      crio-metrics-cert = {
        contents = tls_locally_signed_cert.crio-metrics.cert_pem
      }
      crio-metrics-key = {
        contents = tls_private_key.crio-metrics.private_key_pem
      }
    } :
    key => merge(f, {
      path = "${local.config_path}/${key}.pem"
    })
  }

  kubeconfig = {
    for key, f in {
      node-bootstrap = {
        contents = module.node-bootstrap-kubeconfig.manifest
      }
    } :
    key => merge(f, {
      path = "${local.config_path}/${key}.kubeconfig"
    })
  }

  config = {
    for key, f in {
      kubelet = {
        contents = yamlencode({
          kind                     = "KubeletConfiguration"
          apiVersion               = "kubelet.config.k8s.io/v1beta1"
          containerRuntimeEndpoint = "unix://${local.crio_socket}"
          cgroupDriver             = "systemd"
          cgroupsPerQOS            = false
          authentication = {
            anonymous = {
              enabled = false
            }
            webhook = {
              enabled = true
            }
            x509 = {
              clientCAFile = local.pki.ca-cert.path
            }
          }
          authorization = {
            mode = "Webhook"
          }
          staticPodPath = var.static_pod_path
          address       = cidrhost(var.node_prefix, var.host_netnum)
          port          = var.ports.kubelet
          clusterDomain = var.cluster_domain
          clusterDNS = [
            var.cluster_dns_ip,
          ]
          imageGCHighThresholdPercent = 64
          imageGCLowThresholdPercent  = 60
          imageMinimumGCAge           = "48h"
          resolvConf                  = "/run/systemd/resolve/resolv.conf"
          runtimeRequestTimeout       = "15m"
          rotateCertificates          = true
          serverTLSBootstrap          = true
          shutdownGracePeriodByPodPriority = [
            {
              priority                   = 0
              shutdownGracePeriodSeconds = var.graceful_shutdown_delay
            },
            {
              priority                   = 2000000000
              shutdownGracePeriodSeconds = var.graceful_shutdown_delay
            },
            {
              priority                   = 2000001000
              shutdownGracePeriodSeconds = var.graceful_shutdown_delay
            },
          ]
          containerLogMaxSize  = "10Mi"
          containerLogMaxFiles = 2
          evictionHard = {
            "memory.available"   = "2%"
            "nodefs.available"   = "2%"
            "imagefs.available"  = "2%"
            "imagefs.inodesFree" = "2%"
          }
          registerNode           = true
          failSwapOn             = false
          enforceNodeAllocatable = []
          enableSystemLogHandler = true
          enableSystemLogQuery   = true
          featureGates           = var.feature_gates
        })
      }
    } :
    key => merge(f, {
      path = "${local.config_path}/${key}.config"
    })
  }

  ignition_snippets = concat([
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      butane_version            = var.butane_version
      name                      = var.name
      node_ip                   = cidrhost(var.node_prefix, var.host_netnum)
      fw_mark                   = var.fw_mark
      config_path               = local.config_path
      kubelet_root_path         = var.kubelet_root_path
      static_pod_path           = var.static_pod_path
      kubelet_config_path       = local.config.kubelet.path
      bootstrap_kubeconfig_path = local.kubeconfig.node-bootstrap.path
      kubeconfig_path           = "${local.config_path}/kubelet.kubeconfig"
      container_storage_path    = var.container_storage_path
      cni_bin_path              = var.cni_bin_path
      cni_config_path           = var.cni_config_path
      crio_socket               = local.crio_socket
      cni_bridge_interface_name = var.cni_bridge_interface_name
      graceful_shutdown_delay   = var.graceful_shutdown_delay
      kubernetes_pod_prefix     = var.kubernetes_pod_prefix
      node_prefix               = var.node_prefix
      crio_metrics_cert_path    = local.pki.crio-metrics-cert.path
      crio_metrics_key_path     = local.pki.crio-metrics-key.path
      ports                     = var.ports
      internal_registries = [
        for _, reg in var.internal_registries :
        merge(reg, {
          client_cert_pem = tls_locally_signed_cert.registry-client[reg.prefix].cert_pem
          client_key_pem  = tls_private_key.registry-client[reg.prefix].private_key_pem
          ca_cert_pem     = var.registry_ca.cert_pem
        })
      ]
    })
    ], [
    yamlencode({
      variant = "fcos"
      version = var.butane_version
      storage = {
        files = [
          for _, f in concat(
            values(local.pki),
            values(local.kubeconfig),
            values(local.config),
          ) :
          merge({
            mode = 384
            }, f, {
            contents = {
              inline = f.contents
            }
          })
        ]
      }
    }),
  ])
}

module "node-bootstrap-kubeconfig" {
  source             = "../../../modules/kubeconfig"
  cluster_name       = var.cluster_name
  user               = var.kubelet_bootstrap_user
  apiserver_endpoint = var.apiserver_endpoint
  ca_cert_pem        = var.kubernetes_ca.cert_pem
  client_cert_pem    = tls_locally_signed_cert.bootstrap.cert_pem
  client_key_pem     = tls_private_key.bootstrap.private_key_pem
}
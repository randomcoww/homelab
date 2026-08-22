locals {
  config_path = "${var.config_base_path}/${var.name}"

  kubeconfig_files = {
    for key, f in {
      "node-bootstrap.kubeconfig" = module.node-bootstrap-kubeconfig.manifest
    } :
    key => {
      mode = 384
      path = "${local.config_path}/${key}"
      contents = {
        inline = f
      }
    }
  }

  config_files = {
    for key, f in {
      "kubelet.config" = yamlencode({
        kind                     = "KubeletConfiguration"
        apiVersion               = "kubelet.config.k8s.io/v1beta1"
        containerRuntimeEndpoint = "unix://${var.crio_socket}"
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
            clientCAFile = local.pki_files["kubernetes-ca.crt"].path
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
    } :
    key => {
      mode = 384
      path = "${local.config_path}/${key}"
      contents = {
        inline = f
      }
    }
  }

  pki_files = {
    for key, f in {
      "kubernetes-ca.crt"  = var.kubernetes_ca.cert_pem
      "crio-metrics.crt"   = tls_locally_signed_cert.crio-metrics.cert_pem
      "crio-metrics.key"   = tls_private_key.crio-metrics.private_key_pem
      "vlagent-ca.crt"     = var.vlagent_ca.cert_pem
      "vlagent-client.crt" = tls_locally_signed_cert.vlagent-client.cert_pem
      "vlagent-client.key" = tls_private_key.vlagent-client.private_key_pem
    } :
    key => {
      mode = 384
      path = "${local.config_path}/${key}"
      contents = {
        inline = f
      }
    }
  }
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
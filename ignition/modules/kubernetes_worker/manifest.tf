locals {
  config_path = "${var.config_base_path}/${var.name}"
  crio_socket = "/run/crio/crio.sock"

  pki = {
    for key, f in {
      ca-cert = {
        contents = var.ca.cert_pem
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
          address       = "0.0.0.0"
          port          = var.ports.kubelet
          clusterDomain = var.cluster_domain
          clusterDNS = [
            var.cluster_dns_ip,
          ]
          imageGCHighThresholdPercent = 1
          imageGCLowThresholdPercent  = 0
          imageMinimumGCAge           = "1h"
          resolvConf                  = "/run/systemd/resolve/resolv.conf"
          runtimeRequestTimeout       = "15m"
          rotateCertificates          = true
          serverTLSBootstrap          = true
          shutdownGracePeriodByPodPriority = [
            {
              priority                   = 0
              shutdownGracePeriodSeconds = 180
            }
          ]
          containerLogMaxSize  = "10Mi"
          containerLogMaxFiles = 2
          evictionHard = {
            "imagefs.available" = "1%"
            "memory.available"  = "100Mi"
            "nodefs.available"  = "1%"
            "nodefs.inodesFree" = "1%"
          }
          registerNode           = true
          failSwapOn             = false
          enforceNodeAllocatable = []
        })
      }
    } :
    key => merge(f, {
      path = "${local.config_path}/${key}.config"
    })
  }

  ignition_snippet = yamlencode({
    variant = "fcos"
    version = var.ignition_version
    systemd = {
      units = [
        {
          name    = "crio.service"
          enabled = true
          dropins = [
            {
              name     = "10-local-fs-wait.conf"
              contents = <<-EOF
              [Unit]
              Wants=local-fs.target
              After=local-fs.target
              EOF
            },
          ]
        },
        {
          name    = "kubelet.service"
          enabled = true
          dropins = [
            {
              name     = "10-worker.conf"
              contents = <<-EOF
              [Unit]
              Wants=crio.service
              After=crio.service
              Wants=local-fs.target
              After=local-fs.target

              [Service]
              ExecStartPre=/usr/bin/mkdir -p ${var.static_pod_path}
              ExecStart=
              ExecStart=/usr/bin/kubelet \
                --exit-on-lock-contention \
                --lock-file=/var/run/lock/kubelet.lock \
                --node-ip=${var.node_ip} \
                --root-dir=${var.kubelet_root_path} \
                --bootstrap-kubeconfig=${local.kubeconfig.node-bootstrap.path} \
                --config=${local.config.kubelet.path} \
                --v=2
              EOF
            },
          ]
        }
      ]
    }
    storage = {
      files = [
        for _, f in concat(
          values(local.pki),
          values(local.kubeconfig),
          values(local.config),
          [
            # nf_call_iptables is disabled gloablly except for on CNI interface
            {
              path     = "/etc/udev/rules.d/10-cni-nf-call-iptables.rules"
              contents = <<-EOF
              SUBSYSTEM=="net", ACTION=="add", KERNEL=="${var.cni_bridge_interface_name}", ATTR{bridge/nf_call_iptables}="1"
              EOF
            },
            # inhibit shutdown for graceful node shutdown
            {
              path     = "/etc/systemd/logind.conf.d/10-kubelet-graceful-shutdown.conf"
              contents = <<-EOF
              [Login]
              InhibitDelayMaxSec=180
              EOF
            },
            {
              path     = "/etc/crio/crio.conf.d/10-custom.conf"
              contents = <<-EOF
              [crio]
              root="${var.container_storage_path}"

              [crio.api]
              listen="${local.crio_socket}"

              [crio.image]
              big_files_temporary_dir="${var.container_storage_path}"

              [crio.runtime]
              default_runtime="crun"
              hooks_dir=["/usr/share/containers/oci/hooks.d"]
              selinux=true

              [crio.runtime.runtimes.crun]
              runtime_path="/usr/bin/crun"

              [crio.network]
              plugin_dirs=["/usr/libexec/cni","/opt/cni/bin"]

              [crio.metrics]
              enable_metrics=false

              [crio.tracing]
              enable_tracing=false
              EOF
            },
            {
              path     = "/etc/containers/storage.conf.d/10-root.conf"
              contents = <<-EOF
              [storage]
              graphroot="${var.container_storage_path}"
              EOF
            },
            {
              path     = "/etc/sysctl.d/20-hugepages.conf"
              contents = <<-EOF
              vm.nr_hugepages=1024
              EOF
            },
            {
              path     = "/etc/modules-load.d/20-nvme-tcp.conf"
              contents = <<-EOF
              nvme_tcp
              EOF
            },
          ],
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
  })
}

module "node-bootstrap-kubeconfig" {
  source             = "../kubeconfig"
  cluster_name       = var.cluster_name
  user               = var.node_bootstrap_user
  apiserver_endpoint = var.apiserver_endpoint
  ca_cert_pem        = var.ca.cert_pem
  client_cert_pem    = tls_locally_signed_cert.bootstrap.cert_pem
  client_key_pem     = tls_private_key.bootstrap.private_key_pem
}
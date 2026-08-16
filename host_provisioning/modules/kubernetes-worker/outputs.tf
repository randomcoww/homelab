output "ignition_snippet" {
  value = yamlencode({
    variant = "fcos"
    version = var.butane_version
    systemd = {
      units = [
        {
          name = "docker.service"
          mask = true
        },
        {
          name = "docker.socket"
          mask = true
        },
        {
          name = "containerd.service"
          mask = true
        },
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

                [Service]
                ExecStartPre=/usr/bin/mkdir -p ${var.cni_bin_path} ${var.cni_config_path}
                EOF
            },
          ]
        },
        {
          name    = "kubelet.service"
          enabled = true
          dropins = [
            {
              name     = "20-bootstrap-worker.conf"
              contents = <<-EOF
                [Unit]
                Wants=crio.service
                After=crio.service
                Wants=local-fs.target
                After=local-fs.target
                Before=generate-backup-boot-device.service

                [Service]
                ExecStartPre=/usr/bin/mkdir -p ${var.kubelet_root_path} ${var.static_pod_path} ${local.config_path}
                ExecStart=
                ExecStart=/usr/bin/kubelet \
                --exit-on-lock-contention \
                --lock-file=/var/run/lock/kubelet.lock \
                --node-ip=${cidrhost(var.node_prefix, var.host_netnum)} \
                --cert-dir=${local.config_path} \
                --root-dir=${var.kubelet_root_path} \
                --bootstrap-kubeconfig=${local.kubeconfig_files["node-bootstrap.kubeconfig"].path} \
                --config=${local.config_files["kubelet.config"].path} \
                --kubeconfig=${local.config_path}/kubelet.kubeconfig \
                --v=2
                EOF
            },
          ]
        },
        {
          name    = "nftables@${var.name}.service"
          enabled = true
        },
        {
          name    = "bird.service"
          enabled = true
          dropins = [
            {
              name     = "20-kubelet-dependency.conf"
              contents = <<-EOF
                [Unit]
                Before=kubelet.service
                EOF
            },
          ]
        },
      ]
    }
    storage = {
      files = concat(
        values(local.config_files),
        values(local.kubeconfig_files),
        values(local.pki_files), [

          # TODO: limit access
          {
            path      = "/etc/nftables/${var.name}.nft"
            mode      = 420
            overwrite = true
            contents = {
              inline = <<-EOF
              table inet ${var.name} {
                chain mark-for-accept {
                  meta mark set meta mark | ${var.fw_mark}
                }

                chain input {
                  type filter hook input priority 0; policy accept;
                  tcp dport ${var.ports.kubelet} jump mark-for-accept;
                  ip saddr ${var.kubernetes_pod_prefix} jump mark-for-accept;
                  ip saddr ${var.node_prefix} jump mark-for-accept;
                  ip daddr ${var.node_prefix} jump mark-for-accept;
                }

                chain forward {
                  type filter hook forward priority 0; policy accept;
                  ip saddr ${var.kubernetes_pod_prefix} jump mark-for-accept;
                  ip saddr ${var.node_prefix} jump mark-for-accept;
                  ip daddr ${var.node_prefix} jump mark-for-accept;
                }
              }
              ;
              EOF
            }
          },
          # inhibit shutdown for graceful node shutdown
          {
            path = "/etc/systemd/logind.conf.d/10-kubelet-graceful-shutdown.conf"
            mode = 420
            contents = {
              inline = <<-EOF
              [Login]
              InhibitDelayMaxSec=${var.graceful_shutdown_delay}
              EOF
            }
          },
          {
            path = "/etc/crio/crio.conf.d/20-worker.conf"
            mode = 420
            contents = {
              inline = <<-EOF
              [crio]
              root="${var.container_storage_path}"
              internal_repair=true

              [crio.runtime]
              cgroup_manager="systemd"

              [crio.api]
              listen="${var.crio_socket}"

              [crio.image]
              big_files_temporary_dir="${var.container_storage_path}"
              pull_progress_timeout=0

              [crio.network]
              plugin_dirs=["/var/opt/cni/bin","${var.cni_bin_path}"]
              network_dir="${var.cni_config_path}"

              [crio.metrics]
              enable_metrics=true
              metrics_port=${var.ports.crio_metrics}
              metrics_host="${cidrhost(var.node_prefix, var.host_netnum)}"
              metrics_cert="${local.pki_files["crio-metrics.crt"].path}"
              metrics_key="${local.pki_files["crio-metrics.key"].path}"

              [crio.tracing]
              enable_tracing=false
              EOF
            }
          },

          # needed for hostapd and not needed for cilium
          {
            path = "/etc/sysctl.d/99-bridge-iptables.conf"
            mode = 420
            contents = {
              inline = <<-EOF
              net.bridge.bridge-nf-call-iptables=0
              net.bridge.bridge-nf-call-ip6tables=0
              net.bridge.bridge-nf-call-arptables=0
              EOF
            }
          },

          # Image build dependency
          {
            path = "/etc/modules-load.d/20-uinput.conf"
            mode = 420
            contents = {
              inline = <<-EOF
              uinput
              EOF
            }
          },
          # Sunshine desktop
          {
            path = "/etc/modules-load.d/20-ntsync.conf"
            mode = 420
            contents = {
              inline = <<-EOF
              ntsync
              EOF
            }
          },

          # Internal registry
          {
            path = "/etc/containers/registries.conf.d/10-internal.conf"
            mode = 420
            contents = {
              inline = <<-EOF
%{for _, reg in var.internal_registries}[[registry]]
location = "${reg.location}"
prefix = "${reg.prefix}"
%{endfor~}
EOF
            }
          },
          ], [
          # https://man.archlinux.org/man/containers-certs.d.5.en
          for _, reg in var.internal_registries :
          {
            mode = 384
            path = "/etc/containers/certs.d/${reg.location}/client.cert"
            contents = {
              inline = tls_locally_signed_cert.registry-client[reg.prefix].cert_pem
            }
          }
          ], [
          for _, reg in var.internal_registries :
          {
            mode = 384
            path = "/etc/containers/certs.d/${reg.location}/client.key"
            contents = {
              inline = tls_private_key.registry-client[reg.prefix].private_key_pem
            }
          }
          ], [
          for _, reg in var.internal_registries :
          {
            mode = 384
            path = "/etc/containers/certs.d/${reg.location}/ca.crt"
            contents = {
              inline = var.registry_ca.cert_pem
            }
          }
      ])
    }
  })
}
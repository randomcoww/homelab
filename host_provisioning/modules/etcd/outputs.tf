output "ignition_snippet" {
  value = yamlencode({
    variant = "fcos"
    version = var.butane_version
    storage = {
      files = concat(
        values(local.pki_files), [
          for key, f in {
            "etcd.yaml" = module.etcd-wrapper.manifest
          } :
          {
            mode = 384
            path = "${var.static_pod_path}/${key}"
            contents = {
              inline = f
            }
          }
          ], [
          {
            path = "/etc/sysctl.d/10-time-wait.conf"
            mode = 420
            contents = {
              inline = <<-EOF
              net.ipv4.tcp_tw_reuse=1
              EOF
            }
          },
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
                  tcp dport {${var.ports.etcd_client}, ${var.ports.etcd_peer}, ${var.ports.etcd_metrics}} jump mark-for-accept;
                }

                chain forward {
                  type filter hook forward priority 0; policy accept;
                  tcp dport ${var.ports.etcd_metrics} jump mark-for-accept;
                }
              }
              ;
              EOF
            }
          },
      ])
    }
    systemd = {
      units = [
        {
          name : "nftables@${var.name}.service"
          enabled = true
        },
      ]
    }
  })
}
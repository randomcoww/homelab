output "ignition_snippet" {
  value = yamlencode({
    variant = "fcos"
    version = var.butane_version
    systemd = {
      units = [
        {
          name    = "nftables@${var.name}.service"
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
        {
          name    = "haproxy.service"
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
          for key, f in {
            "apiserver.yaml"          = module.apiserver.manifest
            "controller-manager.yaml" = module.controller-manager.manifest
            "scheduler.yaml"          = module.scheduler.manifest
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
                  tcp dport ${var.ports.apiserver} jump mark-for-accept;
                }
              }
              ;
              EOF
            }
          },

          # local haproxy for apiserver
          # on node drain, apiserver static pod will often go down early breaking further pods from coordinating with apiserver to drain. 
          # allow local apiserver endpoint to keep working
          {
            path = "${var.haproxy_path}/${var.name}.cfg"
            mode = 420
            contents = {
              inline = <<-EOF
              frontend ${var.name}
                bind 0.0.0.0:${var.ports.apiserver}
                mode tcp
                default_backend ${var.name}

              backend ${var.name}
                option httpchk GET /readyz HTTP/1.0
                http-check expect status 200
                mode tcp
                balance leastconn
                default-server verify none check-ssl rise 1 fall 2 maxconn 5000 maxqueue 5000 weight 100
                server local 127.0.0.1:${var.ports.apiserver_backend} check
                server cluster ${var.cluster_apiserver_ip}:443 check
              EOF
            }
          },
          {
            path = "/etc/systemd/network/20-lo.network"
            mode = 420
            contents = {
              inline = <<-EOF
              [Match]
              Name=lo

              [Address]
              Address=${var.apiserver_ip}/32
              Scope=host
              EOF
            }
          },
          {
            path = "${var.bird_path}/apiserver.conf"
            mode = 420
            contents = {
              inline = <<-EOF
%{for host_key, netnum in var.bgp_neighbor_netnums}protocol bgp ${replace(host_key, "-", "_")} {
  debug all;
  local port ${var.ports.bgp} as ${var.bgp_as};
  neighbor ${cidrhost(var.bgp_prefix, netnum)} port ${var.ports.bgp} internal;
  graceful restart;
  direct;
  bfd {
  };
  ipv4 {
    import all;
    export all;
    table ${var.bird_cache_table_name};
  };
}
%{endfor~}
EOF
            }
          },
      ])
    }
  })
}
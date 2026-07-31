output "ignition_snippet" {
  value = yamlencode({
    variant = "fcos"
    version = var.butane_version
    systemd = {
      units = [
        {
          name    = "nftables@gateway.service"
          enabled = true
        },
      ]
    }
    storage = {
      files = concat([
        # https://blog.fhrnet.eu/2019/03/07/ecmp-on-linux/
        {
          path = "/etc/sysctl.d/20-gateway.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              net.ipv4.ip_forward=1
              EOF
          }
        },
        {
          path      = "/etc/nftables/gateway.nft"
          mode      = 420
          overwrite = true
          contents = {
            inline = <<-EOF
              table inet gateway {
                chain mark-for-accept {
                  meta mark set meta mark | ${var.fw_mark}
                }

                chain input {
                  type filter hook input priority -10; policy accept;
                  iifname ${var.keepalived_interface_name} pkttype multicast jump mark-for-accept;
                  iifname {${join(",", var.wan_interface_names)}} meta mark & ${var.fw_mark} == 0x00000000 drop;
                }

                chain forward {
                  type filter hook forward priority 0; policy accept;
                  oifname {${join(",", var.wan_interface_names)}} jump mark-for-accept;
                }

                chain postrouting {
                  type nat hook postrouting priority srcnat + 20; policy accept;
                  oifname {${join(",", var.wan_interface_names)}} masquerade;
                }
              }
              ;
              EOF
          }
        },
        {
          path = "${var.keepalived_path}/gateway.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              vrrp_instance gateway {
                preempt
                state BACKUP
                advert_int 0.2
                virtual_router_id ${var.keepalived_router_id}
                interface ${var.keepalived_interface_name}
                no_accept
                use_vmac
                vmac_xmit_base
                priority 100
                virtual_ipaddress {
                  ${var.keepalived_vip}
                }
                virtual_rules {
                  to all lookup ${var.master_default_route.table_id} priority ${var.master_default_route.table_priority}
                }
                virtual_routes {
                  default dev ${var.keepalived_interface_name} table ${var.slave_default_route.table_id}
                }
              }
              EOF
          }
        },
        # bird
        {
          path = "${var.bird_path}/gateway.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              protocol kernel gateway_kernel {
                learn;
                kernel table ${var.slave_default_route.table_id};
                ipv4 {
                  import all;
                  export none;
                  table ${var.bird_cache_table_name};
                };
              }
              %{for host_key, netnum in var.bgp_neighbor_netnums}
              protocol bgp ${replace(host_key, "-", "_")} {
                debug all;
                source address ${cidrhost(var.node_prefix, var.host_netnum)};
                local port ${var.bgp_port} as ${var.bgp_as_members};
                neighbor ${cidrhost(var.node_prefix, netnum)} port ${var.bgp_port} internal;
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
              %{endfor}
              protocol bgp node {
                debug all;
                source address ${cidrhost(var.node_prefix, var.host_netnum)};
                local port ${var.bgp_port} as ${var.bgp_as};
                neighbor range ${var.node_prefix} port ${var.bgp_port} internal;
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
              protocol bgp service {
                debug all;
                source address ${cidrhost(var.service_prefix, var.host_netnum)};
                local port ${var.bgp_port} as ${var.bgp_as};
                neighbor range ${var.service_prefix} port ${var.bgp_port} as ${var.bgp_as_peer};
                graceful restart;
                direct;
                bfd {
                };
                ipv4 {
                  import all;
                  export all;
                };
              }
              EOF
          }
        },
        ], [
        # DHCP options for WAN
        for _, interface in var.wan_interface_names :
        {
          path = "/etc/systemd/network/20-${interface}.network.d/20-master-default-route.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              [DHCPv4]
              RequestBroadcast=true
              ClientIdentifier=mac
              RouteTable=${var.master_default_route.table_id}
              UseTimezone=false
              EOF
          }
        }
      ])
    }
  })
}
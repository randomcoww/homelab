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
      files = [
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
                  iifname ${var.vrrp_network_config.interface} pkttype multicast jump mark-for-accept;
                  iifname ${var.wan_network_config.interface} meta mark & ${var.fw_mark} == 0x00000000 drop;
                }

                chain forward {
                  type filter hook forward priority 0; policy accept;
                  oifname ${var.wan_network_config.interface} jump mark-for-accept;
                }

                chain postrouting {
                  type nat hook postrouting priority srcnat + 20; policy accept;
                  oifname ${var.wan_network_config.interface} masquerade;
                }
              }
              ;
              EOF
          }
        },
        {
          path = "${var.keepalived_path}/master.sh"
          mode = 448
          contents = {
            # bring wan interface up on transition to master
            # use same mac on WAN across all gateways
            # DHCP routes won't recover unless reconfigure is called
            inline = <<-EOF
              #!/bin/bash
              networkctl reconfigure "${var.wan_network_config.interface}"
              EOF
          }
        },
        {
          path = "${var.keepalived_path}/backup.sh"
          mode = 448
          contents = {
            # take down wan interface on transition to slave
            inline = <<-EOF
              #!/bin/bash
              networkctl down "${var.wan_network_config.interface}"
              EOF
          }
        },
        {
          path = "${var.keepalived_path}/gateway.conf"
          mode = 420
          contents = {
            # Use VIP with network netmask as virtual addr to intentionally create a prefix route
            inline = <<-EOF
vrrp_instance gateway {
  nopreempt
  state BACKUP
  advert_int 1
  virtual_router_id ${var.vrrp_network_config.vrrp_router_id}
  interface ${var.vrrp_network_config.interface}
  accept
  use_vmac
  vmac_xmit_base
  priority 100
  unicast_src_ip ${cidrhost(var.vrrp_network_config.prefix, var.host_netnum)}
  unicast_peer {
%{~for _, netnum in var.member_netnums}
    ${cidrhost(var.vrrp_network_config.prefix, netnum)}
%{endfor~}
  }
  virtual_ipaddress {
    ${var.vrrp_network_config.vips.vrrp}/${var.vrrp_network_config.cidr}
  }
  virtual_rules {
    to all lookup ${var.wan_network_config.table_id} priority ${var.wan_network_config.table_priority}
  }
  virtual_routes {
    default dev ${var.vrrp_network_config.interface} table ${var.bird_cache_table.table_id}
  }
  notify_master "${var.keepalived_path}/master.sh"
  notify_backup "${var.keepalived_path}/backup.sh"
  notify_fault "${var.keepalived_path}/backup.sh"
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
            # Bird peers sharing default gateway and apiserver
            protocol bgp node {
              debug all;
              source address ${cidrhost(var.bgp_prefix, var.host_netnum)};
              local port ${var.bgp_port} as ${var.bgp_as};
              neighbor range ${var.bgp_prefix} port ${var.bgp_port} internal;
              graceful restart;
              direct;
              rr client;
              bfd {
              };
              ipv4 {
                import all;
                export all;
                add paths tx; # allow propagating multiple routes for apiserver
                table ${var.bird_cache_table.name}; # routes from cilium won't be pushed to k8s workers
              };
            }

            # Cilium peers
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
                export none;
              };
            }
            EOF
          }
        },
        # Redundant interface for gateways.
        # Mac is duplicated on nodes. Use mac as client identifier to get the same WAN IP.
        # Passive keeps WAN interfaces down until Keepalived negotiates and brings one up.
        {
          path = "/etc/systemd/network/20-${var.wan_network_config.interface}.network.d/30-master-default-route.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              [Link]
              ActivationPolicy=passive

              [DHCPv4]
              ClientIdentifier=mac
              EOF
          }
        },
      ]
    }
  })
}
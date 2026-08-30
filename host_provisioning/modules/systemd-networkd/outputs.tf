locals {
  interface_defaults = <<-EOF
    [Link]
    ARP=false
    RequiredForOnline=false

    [Network]
    LinkLocalAddressing=false
    DHCP=false
    MulticastDNS=false
    IPv6AcceptRA=false
    IPv6SendRA=false
    LLDP=false
    EmitLLDP=false
    EOF
}

output "ignition_snippet" {
  value = yamlencode({
    variant = "fcos"
    version = var.butane_version
    systemd = {
      units = [
        {
          name    = "systemd-networkd.service"
          enabled = true
        },
        {
          name    = "systemd-networkd-wait-online.service"
          enabled = true
          dropins = [
            {
              name     = "10-short-delay.conf"
              contents = <<-EOF
                [Service]
                ExecStart=
                ExecStart=/usr/lib/systemd/systemd-networkd-wait-online --timeout=10
                EOF
            },
          ]
        },
        {
          name = "NetworkManager.service"
          mask = true
        },
        {
          name = "NetworkManager-wait-online.service"
          mask = true
        },
      ]
    }
    storage = {
      files = concat([
        # Preserve routes created by BIRD during restart/reconfigure
        {
          path = "/etc/systemd/networkd.conf.d/10-preserve-routes.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              [Network]
              ManageForeignNextHops=false
              ManageForeignRoutes=false
              ManageForeignRoutingPolicyRules=false
              EOF
          }
        },

        # systemd-networkd defaults should be unmanaged=true
        # CNI may fail if systemd-networkd tries to manage the interface
        {
          path = "/etc/systemd/network/91-unmanaged.network"
          mode = 420
          contents = {
            inline = <<-EOF
              [Match]
              Name=*

              [Link]
              Unmanaged=true
              EOF
          }
        },
        ], [

        # Hardware interfaces
        for _, iface in concat(var.wired_interfaces, var.wireless_interfaces) :
        # TODO: workaround for r8169 transmit queue timed out issue
        {
          path = "/etc/systemd/network/09-${iface.interface}-r8169.link"
          mode = 420
          contents = {
            inline = <<-EOF
[Match]
PermanentMACAddress=${iface.match_mac}
Driver=r8169

[Link]
Name=${iface.interface}
RxBufferSize=2048
TxBufferSize=2048
%{if contains(keys(iface), "mtu")}MTUBytes=${iface.mtu}
%{endif~}
EOF
          }
        }
        ], [
        for _, iface in concat(var.wired_interfaces, var.wireless_interfaces) :
        {
          path = "/etc/systemd/network/10-${iface.interface}.link"
          mode = 420
          contents = {
            inline = <<-EOF
[Match]
PermanentMACAddress=${iface.match_mac}

[Link]
Name=${iface.interface}
%{if contains(keys(iface), "mtu")}MTUBytes=${iface.mtu}
%{endif~}
EOF
          }
        }
        ], [
        for _, iface in concat(var.wired_interfaces, var.wireless_interfaces) :
        {
          path = "/etc/systemd/network/20-${iface.interface}.network"
          mode = 420
          contents = {
            inline = <<-EOF
              [Match]
              PermanentMACAddress=${iface.match_mac}

              ${local.interface_defaults~}
              EOF
          }
        }
        ], [

        # VLAN interfaces
        for _, iface in var.vlan_interfaces :
        {
          path = "/etc/systemd/network/20-${iface.source}.network.d/10-vlan-${iface.interface}.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              [Network]
              VLAN=${iface.interface}
              EOF
          }
        }
        ], [
        for _, iface in var.vlan_interfaces :
        {
          path = "/etc/systemd/network/12-${iface.interface}.netdev"
          mode = 420
          contents = {
            inline = <<-EOF
[NetDev]
Name=${iface.interface}
Kind=vlan
MACAddress=${lookup(iface, "mac", "none")}
%{if contains(keys(iface), "mtu")}MTUBytes=${iface.mtu}
%{endif~}

[VLAN]
Id=${iface.vlan_id}
EOF
          }
        }
        ], [
        for _, iface in var.vlan_interfaces :
        {
          path = "/etc/systemd/network/20-${iface.interface}.network"
          mode = 420
          contents = {
            inline = <<-EOF
              [Match]
              Name=${iface.interface}

              ${local.interface_defaults~}
              EOF
          }
        }
        ], [

        # MACVLAN interfaces
        # Set parent interface ARP on that it will work on the macvlan if enabled
        for _, iface in var.macvlan_interfaces :
        {
          path = "/etc/systemd/network/20-${iface.source}.network.d/10-macvlan-${iface.interface}.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              [Link]
              ARP=true

              [Network]
              MACVLAN=${iface.interface}
              EOF
          }
        }
        ], [
        for _, iface in var.macvlan_interfaces :
        {
          path = "/etc/systemd/network/12-${iface.interface}.netdev"
          mode = 420
          contents = {
            inline = <<-EOF
              [NetDev]
              Name=${iface.interface}
              Kind=macvlan
              MACAddress=${lookup(iface, "mac", "none")}

              [MACVLAN]
              Mode=${lookup(iface, "macvlan_mode", "private")}
              EOF
          }
        }
        ], [
        for _, iface in var.macvlan_interfaces :
        {
          path = "/etc/systemd/network/20-${iface.interface}.network"
          mode = 420
          contents = {
            inline = <<-EOF
              [Match]
              Name=${iface.interface}

              ${local.interface_defaults~}
              EOF
          }
        }
        ], [
        for _, iface in var.macvlan_interfaces :
        # arp sysctl for macvlan parent
        {
          path = "/etc/sysctl.d/10-interface-arp-${iface.source}.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              net.ipv4.conf.${iface.source}.arp_ignore=1
              net.ipv4.conf.${iface.source}.arp_announce=2
              net.ipv4.conf.${iface.source}.rp_filter=2
              EOF
          }
        }

        # Bridge interfaces
        ], flatten([
          for _, iface in var.bridge_interfaces : [
            for _, source in iface.sources :
            {
              path = "/etc/systemd/network/20-${source}.network.d/10-bridge-${iface.interface}.conf"
              mode = 420
              contents = {
                inline = <<-EOF
                [Network]
                Bridge=${iface.interface}
                EOF
              }
            }
          ]
        ]), [
        for _, iface in var.bridge_interfaces :
        {
          path = "/etc/systemd/network/12-${iface.interface}.netdev"
          mode = 420
          contents = {
            inline = <<-EOF
[NetDev]
Name=${iface.interface}
Kind=bridge
MACAddress=${lookup(iface, "mac", "none")}
%{if contains(keys(iface), "mtu")}MTUBytes=${iface.mtu}
%{endif~}
EOF
          }
        }
        ], [
        for _, iface in var.bridge_interfaces :
        {
          path = "/etc/systemd/network/20-${iface.interface}.network"
          mode = 420
          contents = {
            inline = <<-EOF
              [Match]
              Name=${iface.interface}

              ${local.interface_defaults~}
              EOF
          }
        }

        ], [
        # Interface config override
        for _, iface in var.interface_overrides :
        {
          path = "/etc/systemd/network/20-${iface.interface}.network.d/20-default-network.conf"
          mode = 420
          contents = {
            inline = <<-EOF
[Link]
ARP=true
RequiredForOnline=${lookup(iface, "enable_netnum", false)}

[DHCPv4]
%{if contains(keys(iface), "metric")}RouteMetric=${iface.metric}
%{endif~}
UseDNS=${lookup(iface, "enable_dns", false)}
UseNTP=false
UseMTU=true
UseHostname=false
UseTimezone=false
UseDomains=${lookup(iface, "enable_dns", false)}
UseRoutes=${!lookup(iface, "enable_netnum", false) && lookup(iface, "enable_routes", true)}
RoutesToDNS=false
RoutesToNTP=false
%{if contains(keys(iface), "table_id")}RouteTable=${iface.table_id}
%{endif~}

[Network]
LinkLocalAddressing=false
DHCP=${lookup(iface, "enable_dhcp", false)}
MulticastDNS=${lookup(iface, "enable_mdns", false)}
ConfigureWithoutCarrier=true
%{if contains(keys(iface), "enable_netnum") && contains(keys(iface), "prefix")~}

[Address]
Address=${cidrhost(iface.prefix, var.host_netnum)}/${iface.cidr}
AddPrefixRoute=false

[Route]
Protocol=kernel
Scope=link
PreferredSource=${cidrhost(iface.prefix, var.host_netnum)}
Destination=${iface.prefix}
%{if contains(keys(iface), "metric")}Metric=${iface.metric}
%{endif~}
%{if contains(keys(iface), "table_id")~}
Table=${iface.table_id}

[RoutingPolicyRule]
Table=${iface.table_id}
From=${iface.prefix}
%{if contains(keys(iface), "table_priority")}Priority=${iface.table_priority}
%{endif~}
%{endif~}
%{endif~}
EOF
          }
        }
        ], [

        # arp sysctl for each interface
        {
          path = "/etc/sysctl.d/10-interface-arp.conf"
          mode = 420
          contents = {
            inline = <<-EOF
%{for _, iface in var.interface_overrides}net.ipv4.conf.${iface.interface}.arp_ignore=1
net.ipv4.conf.${iface.interface}.arp_announce=2
net.ipv4.conf.${iface.interface}.rp_filter=2
%{endfor~}
EOF
          }
        },
      ])
    }
  })
}
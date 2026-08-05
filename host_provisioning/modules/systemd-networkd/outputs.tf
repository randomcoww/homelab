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
        for _, iface in var.physical_interfaces :
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
              MTUBytes=${lookup(iface, "mtu", 1500)}
              EOF
          }
        }
        ], [
        for _, iface in var.physical_interfaces :
        {
          path = "/etc/systemd/network/10-${iface.interface}.link"
          mode = 420
          contents = {
            inline = <<-EOF
              [Match]
              PermanentMACAddress=${iface.match_mac}

              [Link]
              Name=${iface.interface}
              MTUBytes=${lookup(iface, "mtu", 1500)}
              EOF
          }
        }
        ], [
        for _, iface in var.physical_interfaces :
        {
          path = "/etc/systemd/network/20-${iface.interface}.network"
          mode = 420
          contents = {
            inline = <<-EOF
              [Match]
              PermanentMACAddress=${iface.match_mac}

              [Link]
              ARP=false
              RequiredForOnline=false

              [Network]
              LinkLocalAddressing=false
              DHCP=false
              MulticastDNS=false
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
              MTUBytes=${lookup(iface, "mtu", 1500)}

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

              [Link]
              ARP=false
              RequiredForOnline=false

              [Network]
              LinkLocalAddressing=false
              DHCP=false
              MulticastDNS=false
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
              MTUBytes=${lookup(iface, "mtu", 1500)}
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

              [Link]
              ARP=false
              RequiredForOnline=false

              [Network]
              LinkLocalAddressing=false
              DHCP=false
              MulticastDNS=false
              EOF
          }
        }

        ], [
        # Interface config override
        for _, iface in var.network_overrides :
        {
          path = "/etc/systemd/network/20-${iface.interface}.network.d/20-default-network.conf"
          mode = 420
          contents = {
            inline = <<-EOF
[Link]
ARP=true
RequiredForOnline=${lookup(iface, "enable_netnum", false)}

[DHCPv4]
%{if contains(keys(iface), "metric")}RouteMetric=${iface.metric}%{endif~}
UseDNS=${lookup(iface, "enable_dns", false)}
UseNTP=false
UseHostname=false
UseTimezone=false
UseDomains=${lookup(iface, "enable_dns", false)}
UseRoutes=${!lookup(iface, "enable_netnum", false) && lookup(iface, "enable_routes", true)}
RoutesToDNS=false
RoutesToNTP=false
%{if contains(keys(iface), "table_id")}RouteTable=${iface.table_id}%{endif~}

[Network]
LinkLocalAddressing=false
DHCP=${lookup(iface, "enable_dhcp", false)}
MulticastDNS=${lookup(iface, "enable_mdns", false)}
ConfigureWithoutCarrier=true
%{if contains(keys(iface), "enable_netnum") && contains(keys(iface), "prefix")~}

[Address]
Address=${cidrhost(iface.prefix, var.host_netnum)}/${iface.prefix}
AddPrefixRoute=false

[Route]
Protocol=kernel
Scope=link
PreferredSource=${cidrhost(iface.prefix, var.host_netnum)}
Destination=${iface.prefix}
%{if contains(keys(iface), "metric")}Metric=${iface.metric}%{endif~}
%{if contains(keys(iface), "table_id")~}
Table=${iface.table_id}

[RoutingPolicyRule]
Table=${iface.table_id}
From=${iface.prefix}
%{if contains(keys(iface), "table_priority")}Priority=${iface.table_priority}%{endif~}
%{endif~}
%{endif~}
EOF
          }
        }
      ])
    }
  })
}
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
          path = "/etc/systemd/network/91-default.network"
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
        for name, iface in var.physical_interfaces :
        # TODO: workaround for r8169 transmit queue timed out issue
        {
          path = "/etc/systemd/network/09-${name}-r8169.link"
          mode = 420
          contents = {
            inline = <<-EOF
              [Match]
              PermanentMACAddress=${iface.match_mac}
              Driver=r8169

              [Link]
              MTUBytes=${lookup(iface, "mtu", 1500)}
              Name=${name}
              RxBufferSize=2048
              TxBufferSize=2048
              EOF
          }
        }
        ], [
        for name, iface in var.physical_interfaces :
        {
          path = "/etc/systemd/network/10-${name}.link"
          mode = 420
          contents = {
            inline = <<-EOF
              [Match]
              PermanentMACAddress=${iface.match_mac}

              [Link]
              MTUBytes=${lookup(iface, "mtu", 1500)}
              Name=${name}
              EOF
          }
        }
        ], [
        for name, iface in var.physical_interfaces :
        {
          path = "/etc/systemd/network/20-${name}.network"
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
        for name, iface in var.vlan_interfaces :
        {
          path = "/etc/systemd/network/20-${iface.source}.network.d/10-vlan-${name}.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              [Network]
              VLAN=${name}
              EOF
          }
        }
        ], [
        for name, iface in var.vlan_interfaces :
        {
          path = "/etc/systemd/network/12-${name}.netdev"
          mode = 420
          contents = {
            inline = <<-EOF
              [NetDev]
              Name=${name}
              Kind=vlan
              MACAddress=${lookup(iface, "mac", "none")}

              [VLAN]
              Id=${iface.vlan_id}
              EOF
          }
        }
        ], [
        for name, iface in var.vlan_interfaces :
        {
          path = "/etc/systemd/network/20-${name}.network"
          mode = 420
          contents = {
            inline = <<-EOF
              [Match]
              Name=${name}

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

        # Interface config for each network
        for name, config in var.networks :
        {
          path = "/etc/systemd/network/20-${config.interface}.network.d/20-${name}.conf"
          mode = 420
          contents = {
            inline = <<-EOF
              [Link]
              ARP=true
              RequiredForOnline=${lookup(config, "enable_netnum", false)}
              MTUBytes=${lookup(config, "mtu", 1500)}

              [DHCPv4]
              RouteMetric=${lookup(config, "metric", 1024)}
              UseDNS=${lookup(config, "enable_dns", false)}
              UseNTP=false
              UseHostname=false
              UseTimezone=false
              UseDomains=${lookup(config, "enable_dns", false)}
              UseRoutes=${!lookup(config, "enable_netnum", false) && lookup(config, "enable_routes", true)}
              RoutesToDNS=false
              RoutesToNTP=false
              %{if contains(keys(config), "table_id")}
              RouteTable=${config.table_id}
              %{endif}

              [Network]
              LinkLocalAddressing=false
              DHCP=${lookup(config, "enable_dhcp", false)}
              MulticastDNS=${lookup(config, "enable_mdns", false)}
              ConfigureWithoutCarrier=true
              %{if lookup(config, "enable_netnum", false)}

              [Address]
              Address=${cidrhost(config.prefix, var.host_netnum)}/${config.cidr}
              AddPrefixRoute=false

              [Route]
              Protocol=kernel
              Scope=link
              PreferredSource=${cidrhost(config.prefix, var.host_netnum)}
              Destination=${config.prefix}
              Metric=${lookup(config, "metric", 1024)}
              %{if contains(keys(config), "table_id")}
              Table=${config.table_id}

              [RoutingPolicyRule]
              Table=${config.table_id}
              From=${config.prefix}
              %{if contains(keys(config), "table_priority")}
              Priority=${config.table_priority}
              %{endif}
              %{endif}
              %{endif}
              EOF
          }
        }
      ])
    }
  })
}
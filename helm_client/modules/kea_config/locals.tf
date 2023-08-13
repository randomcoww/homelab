locals {
  peers = [
    for i, ip in var.service_ips :
    {
      name          = "${var.resource_name}-${i}"
      role          = try(element(["primary", "secondary"], i), "backup")
      url           = "http://${ip}:${var.kea_peer_port}/"
      auto-failover = true
    }
  ]

  configs = [
    for i, peer in local.peers :
    {
      ctrl_agent_config = {
        Control-agent = {
          http-host = "0.0.0.0"
          http-port = var.kea_peer_port
          control-sockets = {
            dhcp4 = {
              socket-type = "unix"
              socket-name = "${var.shared_data_path}/kea-dhcp4-ctrl.sock"
            }
          }
        }
      }
      dhcp4_config = {
        Dhcp4 = {
          valid-lifetime = 7200
          renew-timer    = 1800
          rebind-timer   = 3600
          lease-database = {
            type    = "memfile"
            persist = true
            name    = "${var.shared_data_path}/kea-leases4.csv"
          }
          interfaces-config = {
            interfaces = ["*"]
          }
          control-socket = {
            socket-type = "unix"
            socket-name = "${var.shared_data_path}/kea-dhcp4-ctrl.sock"
          }
          hooks-libraries = length(local.peers) > 1 ? [
            {
              library    = "${var.kea_hooks_libraries_path}/libdhcp_lease_cmds.so"
              parameters = {}
            },
            {
              library = "${var.kea_hooks_libraries_path}/libdhcp_ha.so"
              parameters = {
                high-availability = [
                  {
                    this-server-name    = "${peer.name}"
                    mode                = "load-balancing"
                    max-unacked-clients = 0
                    peers               = local.peers
                  },
                ]
              }
            },
          ] : []
          client-classes = [
            {
              name           = "ipxe_detected"
              test           = "substring(option[77].hex,0,4) == 'iPXE'"
              boot-file-name = var.ipxe_script_url
            },
            {
              name           = "ipxe_efi"
              test           = "not(substring(option[77].hex,0,4) == 'iPXE') and (option[93].hex == 0x0007)"
              next-server    = var.tftp_server
              boot-file-name = var.ipxe_boot_path
            },
            # {
            #   name           = "HTTPClient"
            #   test           = "not(substring(option[77].hex,0,4) == 'iPXE') and (option[93].hex == 0x0010)"
            #   boot-file-name = "https://boot.ipxe.org/ipxe.efi"
            #   option-data = [
            #     {
            #       name = "vendor-class-identifier"
            #       data = "HTTPClient"
            #     },
            #   ]
            # },
          ]
          subnet4 = [
            for network_name, network in var.networks :
            {
              subnet = network.prefix,
              option-data = [
                {
                  name = "routers"
                  data = join(",", network.routers)
                },
                {
                  name = "domain-name-servers"
                  data = join(",", network.domain_name_servers)
                },
                {
                  name = "interface-mtu"
                  data = format("%s", network.mtu)
                },
              ]
              pools = [
                for _, pool in network.pools :
                {
                  pool = pool
                }
              ]
            }
          ]
        }
      }
    }
  ]
}
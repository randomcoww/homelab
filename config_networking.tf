locals {
  # do not use #
  base_networks = {
    lan = {
      network = "192.168.126.0"
      cidr    = 23
      vlan_id = 1
      netnums = {
        apiserver      = 2
        forwarding_dns = 2
      }
    }
    sync = {
      network = "192.168.190.0"
      cidr    = 29
      vlan_id = 60
    }
    wan = {
      vlan_id = 30
    }
    metallb = {
      prefix = cidrsubnet("192.168.126.0/23", 2, 1)
      netnums = {
        minio            = 10
        external_dns     = 11
        internal_pxeboot = 12
      }
    }
  }

  base_networks_temp_1 = merge(local.base_networks, {
    for network_name, network in local.base_networks :
    network_name => merge(network, try({
      prefix = "${network.network}/${network.cidr}"
    }, {}))
  })

  networks = merge(local.base_networks_temp_1, {
    for network_name, network in local.base_networks_temp_1 :
    network_name => merge(network, {
      vips = try({
        for service, netnum in network.netnums :
        service => cidrhost(network.prefix, netnum)
      }, {})
      }, try({
        dhcp_range = merge(network.dhcp_range, {
          prefix = cidrsubnet(network.prefix, network.dhcp_range.newbit, network.dhcp_range.netnum)
        })
    }, {}))
  })

  ports = {
    apiserver             = 58081
    controller_manager    = 50252
    scheduler             = 50251
    kubelet               = 50250
    kea_peer              = 58080
    etcd_client           = 58082
    etcd_peer             = 58083
    minio                 = 50256
    minio_console         = 50257
    internal_pxeboot_http = 80
    internal_pxeboot_api  = 50259
  }

  domains = {
    internal_mdns = "local"
    internal      = "fuzzybunny.internal"
    kubernetes    = "cluster.internal"
  }
}
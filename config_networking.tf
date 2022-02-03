locals {
  # do not use #
  base_networks = {
    lan = {
      network = "192.168.126.0"
      cidr    = 23
      vlan_id = 1
    }
    sync = {
      network = "192.168.190.0"
      cidr    = 29
      vlan_id = 60
    }
    wan = {
      vlan_id = 30
    }
    wlan = {
      network = "192.168.62.0"
      cidr    = 24
      vlan_id = 90
    }
    kubernetes_pod = {
      network = "10.244.0.0"
      cidr    = 16
    }
    kubernetes_service = {
      network = "10.96.0.0"
      cidr    = 12
    }
  }

  # use this instead of base_networks #
  networks = merge(local.base_networks, {
    for network_name, network in local.base_networks :
    network_name => merge(network, try({
      prefix = "${network.network}/${network.cidr}"
    }, {}))
  })

  ports = {
    kea_peer              = 58080
    apiserver             = 58081
    controller_manager    = 50252
    scheduler             = 50251
    kubelet               = 50250
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
locals {
  common = merge(local.config, {
    networks = {
      for network_name, network in local.config.networks :
      network_name => merge(network, try({
        prefix = "${network.network}/${network.cidr}"
      }, {}))
    }
  })
}
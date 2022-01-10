# local vars are processed and rerendered here #
locals {
  config = merge(local.preprocess, {
    users = {
      for user_name, user in local.preprocess.users :
      user_name => merge(user, lookup(var.users, user_name, {}))
    }

    networks = {
      for network_name, network in local.preprocess.networks :
      network_name => merge(network, try({
        prefix = "${network.network}/${network.cidr}"
      }, {}))
    }
  })
}
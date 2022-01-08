locals {
  config = merge(local.preprocess, {
    networks = {
      for network_name, network in local.preprocess.networks :
      network_name => merge(network, try({
        prefix = "${network.network}/${network.cidr}"
      }, {}))
    }
  })

  # assign PXE boot macaddresses in some way
  # these are internal to each hypervisor and may duplicate across hardware hosts
  hypervisor_guest_config = merge(local.hypervisor_guest_preprocess, {
    for hypervisor_name, hypervisor in local.hypervisor_guest_preprocess :
    hypervisor_name => merge(hypervisor, {
      guests = merge(hypervisor.guests, {
        for i, guest_name in sort(keys(hypervisor.guests)) :
        guest_name => merge(hypervisor.guests[guest_name], {
          pxeboot_macaddress = join("-", regexall("..", format("%x", local.config.pxeboot_macaddress_base + i)))
        })
      })
    })
  })
}
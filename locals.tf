# local vars are processed and rerendered here #
locals {
  config = merge(local.preprocess, {
    networks = {
      for network_name, network in local.preprocess.networks :
      network_name => merge(network, try({
        prefix = "${network.network}/${network.cidr}"
      }, {}))
    }

    # auto assign internal mac based on this for PXE boot
    pxeboot_macaddress_base = 90520730730496
  })

  hypervisor_endpoints = {
    for host_key in keys(local.hypervisor_hostclass_config.hosts) :
    host_key => {
      matchbox_rpc_endpoint  = module.template-hypervisor[host_key].matchbox_rpc_endpoints.lan[0]
      matchbox_http_endpoint = module.template-hypervisor[host_key].matchbox_http_endpoint
      libvirt_endpoint       = module.template-hypervisor[host_key].libvirt_endpoints.lan[0]
    }
  }

  # all ignition config by host key
  guest_ignition_config = merge({
    for host_key in keys(local.gateway_hostclass_config.hosts) :
    host_key => {
      ignition        = data.ct_config.gateway[host_key].rendered
      guest_interface = module.template-gateway-guest_interfaces[host_key].interfaces.internal.interface_name
    }
    }, {
    for host_key in keys(local.ns_hostclass_config.hosts) :
    host_key => {
      ignition        = data.ct_config.ns[host_key].rendered
      guest_interface = module.template-ns-guest_interfaces[host_key].interfaces.internal.interface_name
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
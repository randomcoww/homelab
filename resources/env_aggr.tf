locals {
  #### Merge component params with host params
  # Map node -> component
  aggr_node_components = transpose({
    for k, v in local.components :
    k => v.nodes
  })

  aggr_components = {
    for node, components in local.aggr_node_components :
    node => merge([
      for component in components : {
        for k, v in local.components[component] :
        k => v
        if ! contains(["nodes"], k)
      }
      ]...
    )
  }

  aggr_component_params = {
    for host, params in local.hosts :
    host => merge(
      lookup(local.aggr_components, host, {}),
      {
        components = lookup(local.aggr_node_components, host, [])
      }
    )
  }

  aggr_host_pre1 = {
    for host, params in local.hosts :
    host => merge(
      lookup(local.aggr_component_params, host, {}),
      params,
    )
  }

  #### Merge network params with host network
  aggr_network_params = {
    for host, params in local.aggr_host_pre1 :
    host => {
      network = [
        for n in lookup(params, "network", []) :
        merge(lookup(local.networks, lookup(n, "label", lookup(n, "if", "placeholder")), {}),
          n, {
            label = lookup(n, "label", lookup(n, "if", "placeholder"))
        })
      ]
    }
  }

  # Map hwif -> vlan interfaces
  aggr_hwif_children = {
    for host, params in local.aggr_network_params :
    host => transpose({
      for n in params.network :
      n.label => compact([lookup(n, "hwif", null)])
    })
  }

  aggr_hwif_params = {
    for host, params in local.aggr_host_pre1 :
    host => {
      hwif = [
        for h in lookup(params, "hwif", []) :
        merge(h, {
          label    = lookup(h, "label", lookup(h, "if", "placeholder"))
          children = lookup(local.aggr_hwif_children[host], h.label, [])
        })
      ]
    }
  }

  aggr_networks_by_key = {
    for host, params in local.aggr_network_params :
    host => {
      networks_by_key = {
        for n in params.network :
        n.label => n
      }
    }
  }

  aggr_hwif_by_key = {
    for host, params in local.aggr_hwif_params :
    host => {
      hwif_by_key = {
        for n in params.hwif :
        n.label => n
      }
    }
  }

  aggr_metadata = {
    for host, params in local.aggr_host_pre1 :
    host => {
      metadata = merge(
        lookup(local.networks, lookup(lookup(params, "metadata", {}), "label", ""), {}),
        lookup(params, "metadata", {})
      )
    }
  }

  #### Build all
  aggr_host_pre2 = {
    for host, params in local.aggr_host_pre1 :
    host => merge(
      params,
      lookup(local.aggr_network_params, host, {}),
      lookup(local.aggr_networks_by_key, host, {}),
      lookup(local.aggr_hwif_params, host, {}),
      lookup(local.aggr_hwif_by_key, host, {}),
      lookup(local.aggr_metadata, host, {}),
    )
  }

  aggr_host_pre3 = {
    for host, params in local.aggr_host_pre2 :
    host => merge(
      params,
      {
        hostname = join(".", [host, local.domains.mdns])
        hostdev  = lookup(params, "hostdev", [])
        disk = [
          for d in lookup(params, "disk", []) :
          merge(d, {
            systemd_unit_name = join("-", compact(split("/", replace(d.mount_path, "-", "\\x2d"))))
          })
        ]
      }
    )
  }

  #### Final aggregate
  aggr_hosts = {
    for host, params in local.aggr_host_pre3 :
    host => merge(
      params,
      {
        libvirt_domains = [
          for d in lookup(params, "libvirt_domains", []) :
          merge(d, {
            host = merge(local.aggr_host_pre3[d.node], d)
          })
        ]
      }
    )
  }

  ############################################
  # # Map guest -> host
  # aggr_guest_hypervisors = transpose({
  #   for host, params in local.hosts :
  #   host => [
  #     for domain in lookup(params, "libvirt_domains", []) :
  #     domain.node
  #   ]
  # })

  # # Add hostdev by hypervisor
  # aggr_libvirt = {
  #   for host, params in local.hosts :
  #   host => {
  #     hostdev = {
  #       for hypervisor in lookup(local.aggr_guest_hypervisors, host, []) :
  #       hypervisor => [
  #         for dev in lookup(params, "hostdev", []) :
  #         lookup(lookup(local.hosts[hypervisor], "dev", {}), dev, {})
  #       ]
  #     }
  #   }
  # }
}


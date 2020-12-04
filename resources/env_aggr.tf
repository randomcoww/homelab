locals {
  # Pick a start value for metadata link mac
  # 52-54-00-00-00-00
  metadata_mac_base = 90520730730496

  #### Add services to networks where vlan matches
  aggr_services_by_vlan_pre1 = {
    for service, params in local.services :
    lookup(params, "vlan", "default") => [{
      "${service}" = params
    }]...
  }

  aggr_services_by_vlan = {
    for vlan, services in local.aggr_services_by_vlan_pre1 :
    vlan => merge(
      flatten(services)...
    )
  }

  # Add services to networks
  aggr_networks = {
    for network, params in local.networks :
    network => merge(
      params,
      {
        services = lookup(local.aggr_services_by_vlan, network, {})
      }
    )
  }

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
      {
        host = host
      }
    )
  }

  #### Merge network params with host network
  aggr_network_params = {
    for host, params in local.aggr_host_pre1 :
    host => {
      network = [
        for n in lookup(params, "network", []) :
        merge(lookup(local.aggr_networks, lookup(n, "vlan", "default"), {}),
          n, {
            label = lookup(n, "label", lookup(n, "vlan", "default"))
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
        for n in lookup(params, "hwif", []) :
        merge(n, {
          children = lookup(local.aggr_hwif_children[host], n.label, [])
        })
      ]
    }
  }

  aggr_metadata_params = {
    # for host, params in local.aggr_host_pre1 :
    for i, params in values(local.aggr_host_pre1) :
    params.host => {
      metadata = merge(
        lookup(local.aggr_networks, lookup(lookup(params, "metadata", {}), "vlan", "default"), {}),
        lookup(params, "metadata", {}),
        {
          label = lookup(lookup(params, "metadata", {}), "label", lookup(lookup(params, "metadata", {}), "vlan", "default"))
          # Need any unique mac that both libvirt and matchbox know about
          mac = join("-", regexall("..", format("%x", local.metadata_mac_base + i)))
        }
      )
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

  #### Build all
  aggr_host_pre2 = {
    for host, params in local.aggr_host_pre1 :
    host => merge(
      params,
      lookup(local.aggr_network_params, host, {}),
      lookup(local.aggr_networks_by_key, host, {}),
      lookup(local.aggr_hwif_params, host, {}),
      lookup(local.aggr_hwif_by_key, host, {}),
      lookup(local.aggr_metadata_params, host, {}),
    )
  }

  aggr_host_pre3 = {
    for host, params in local.aggr_host_pre2 :
    host => merge(
      params,
      {
        hostname = join(".", [host, local.domains.internal_mdns])
        hostdev  = lookup(params, "hostdev", [])
        disk = [
          for d in lookup(params, "disk", []) :
          merge(d, {
            systemd_unit_name = join("-", compact(split("/", replace(lookup(d, "mount_path", ""), "-", "\\x2d"))))
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
}
locals {
  #### Merge network params with host network
  aggr_network_params = {
    for host, params in local.hosts :
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
    for host, params in local.hosts :
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

  #### Merge component params with host params

  # Map node -> component
  aggr_node_components = transpose({
    for k, v in local.components :
    k => v.nodes
  })

  # Map worker -> all ignition templates
  aggr_node_ignition_templates = transpose(
    merge([
      for c in values(local.components) :
      transpose({
        for node in c.nodes :
        node => c.ignition_templates
      })
      ]...
    )
  )

  aggr_components = {
    for node, components in local.aggr_node_components :
    node => merge([
      for component in components : {
        for k, v in local.components[component] :
        k => v
        if ! contains(["nodes", "ignition_templates"], k)
      }
      ]...
    )
  }

  aggr_component_params = {
    for host, params in local.hosts :
    host => merge(
      local.aggr_components[host],
      {
        ignition_templates = local.aggr_node_ignition_templates[host]
        components         = local.aggr_node_components[host]
      }
    )
  }

  #### Merge libvirt host params with guest params

  # Map guest -> host
  aggr_guest_hypervisors = transpose({
    for host, params in local.hosts :
    host => [
      for domain in lookup(params, "libvirt_domains", []) :
      domain.node
    ]
  })

  aggr_libvirt = {
    for host, params in local.hosts :
    host => {
      # Add hostdev by hypervisor
      hostdev = {
        for hypervisor in lookup(local.aggr_guest_hypervisors, host, []) :
        hypervisor => [
          for dev in lookup(params, "hostdev", []) :
          lookup(lookup(local.hosts[hypervisor], "dev", {}), dev, {})
        ]
      }
    }
  }

  #### Build all
  aggr_hosts = {
    for host, params in local.hosts :
    host => merge(
      local.aggr_component_params[host],
      params,
      local.aggr_network_params[host],
      local.aggr_networks_by_key[host],
      local.aggr_hwif_params[host],
      local.aggr_hwif_by_key[host],
      {
        hostname = join(".", [host, local.domains.mdns])
        hostdev  = lookup(params, "hostdev", [])
        disk = [
          for d in lookup(params, "disk", []) :
          merge(d, {
            systemd_unit_name = join("-", compact(split("/", replace(d.mount_path, "-", "\\x2d"))))
          })
        ]
      },
      local.aggr_libvirt[host],
    )
  }
}
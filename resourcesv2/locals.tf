locals {
  aggr_network = {
    for host, params in local.hosts :
    host => {
      network = [
        for n in params.network :
        merge(lookup(local.networks, lookup(n, "label", lookup(n, "if", "placeholder")), {}),
          n, {
            label = lookup(n, "label", lookup(n, "if", "placeholder"))
        })
      ]
    }
  }

  aggr_networks_by_key = {
    for host, params in local.aggr_network :
    host => {
      networks_by_key = {
        for n in params.network :
        n.label => n
      }
    }
  }

  aggr_libvirt = {
    for host, params in local.hosts :
    host => {
      libvirt_domains = {
        for k, v in lookup(params, "libvirt_domains", {}) :
        k => {
          nodes    = v
          template = local.libvirt_domain_templates[k]
        }
      }
      libvirt_networks = {
        for k in lookup(local.aggr_network[host], "label", []) :
        k.libvirt_network_pf => {
          pf       = k.if
          template = local.libvirt_network_templates[k.libvirt_network_pf]
        }
        if lookup(k, "libvirt_network_pf", null) != null
      }
    }
  }

  aggr_hosts = {
    for host, params in local.hosts :
    host => merge(
      params,
      local.aggr_network[host],
      local.aggr_networks_by_key[host],
      local.aggr_libvirt[host],
      {
        hostname = join(".", [host, local.domains.mdns])
        disk     = lookup(params, "disk", [])
        hostdev  = lookup(params, "hostdev", [])
      }
    )
  }
}
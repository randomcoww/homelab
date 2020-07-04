##
## Write config to each libvirt host
## Hardcode each libvirt host until for_each module becomes available
##
module "libvirt-kvm-0" {
  source = "../modulesv2/libvirt"

  endpoint = module.hypervisor.libvirt_endpoints.kvm-0.endpoint
  domains = merge([
    for params in values(local.aggr_hosts.kvm-0.libvirt_domains) :
    {
      for node in params.nodes :
      node => chomp(templatefile(params.template, {
        name         = node
        p            = local.aggr_hosts[node]
        hypervisor_p = local.aggr_hosts.kvm-0
      }))
    }]...
  )
  networks = {
    for name, params in local.aggr_hosts.kvm-0.libvirt_networks :
    name => chomp(templatefile(params.template, {
      name = name
      pf   = params.pf
    }))
  }
}

module "libvirt-kvm-1" {
  source = "../modulesv2/libvirt"

  endpoint = module.hypervisor.libvirt_endpoints.kvm-1.endpoint
  domains = merge([
    for params in values(local.aggr_hosts.kvm-1.libvirt_domains) :
    {
      for node in params.nodes :
      node => chomp(templatefile(params.template, {
        name         = node
        p            = local.aggr_hosts[node]
        hypervisor_p = local.aggr_hosts.kvm-1
      }))
    }]...
  )
  networks = {
    for name, params in local.aggr_hosts.kvm-1.libvirt_networks :
    name => chomp(templatefile(params.template, {
      name = name
      pf   = params.pf
    }))
  }
}

module "libvirt-desktop" {
  source = "../modulesv2/libvirt"

  endpoint = module.hypervisor.libvirt_endpoints.desktop.endpoint
  domains = merge([
    for params in values(local.aggr_hosts.desktop.libvirt_domains) :
    {
      for node in params.nodes :
      node => chomp(templatefile(params.template, {
        name         = node
        p            = local.aggr_hosts[node]
        hypervisor_p = local.aggr_hosts.desktop
      }))
    }]...
  )
  networks = {
    for name, params in local.aggr_hosts.desktop.libvirt_networks :
    name => chomp(templatefile(params.template, {
      name = name
      pf   = params.pf
    }))
  }
}
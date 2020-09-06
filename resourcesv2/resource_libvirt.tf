##
## Write config to each libvirt host
## Hardcode each libvirt host until for_each module becomes available
##
# module "libvirt-hypervisor" {
#   source = "../modulesv2/libvirt"
#   for_each = module.hypervisor.libvirt_endpoints

#   endpoint = each.value.endpoint
#   domains = merge([
#     for params in values(local.aggr_hosts[each.key].libvirt_domains) :
#     {
#       for node in params.nodes :
#       node => chomp(templatefile(params.template, {
#         name         = node
#         p            = local.aggr_hosts[node]
#         hypervisor_p = local.aggr_hosts[each.key]
#       }))
#     }]...
#   )
#   networks = {
#     for name, params in local.aggr_hosts[each.key].libvirt_networks :
#     name => chomp(templatefile(params.template, {
#       name = name
#       pf   = params.pf
#     }))
#   }
# }

module "libvirt-kvm-0" {
  source = "../modulesv2/libvirt"

  endpoint = module.hypervisor.libvirt_endpoints.kvm-0.endpoint
  domains = {
    for v in local.aggr_hosts.kvm-0.libvirt_domains :
    v.node => chomp(local.aggr_hosts[v.node].libvirt_domain_template, {
      name = v.node
      p    = local.aggr_hosts[v.node]
      hwif = v.hwif
    })
  }
  networks = {
    for v in local.aggr_hosts.kvm-0.hwif :
    v.node => chomp(local.aggr_hosts.kvm-0.libvirt_network_template, v)
  }
}

module "libvirt-kvm-1" {
  source = "../modulesv2/libvirt"

  endpoint = module.hypervisor.libvirt_endpoints.kvm-1.endpoint
  domains = {
    for v in local.aggr_hosts.kvm-1.libvirt_domains :
    v.node => chomp(local.aggr_hosts[v.node].libvirt_domain_template, {
      name = v.node
      p    = local.aggr_hosts[v.node]
      hwif = v.hwif
    })
  }
  networks = {
    for v in local.aggr_hosts.kvm-1.hwif :
    v.node => chomp(local.aggr_hosts.kvm-0.libvirt_network_template, v)
  }
}
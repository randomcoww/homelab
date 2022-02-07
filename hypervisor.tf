# module "hypervisor-common" {
#   source = "./modules/hypervisor_common"
# }

# module "ignition-hypervisor" {
#   for_each = {
#     for host_key in [
#       "aio-0",
#     ] :
#     host_key => local.hosts[host_key]
#   }

#   source    = "./modules/hypervisor"
#   dns_names = [each.value.hostname]
#   ip_addresses = compact(concat(["127.0.0.1"], flatten([
#     for interface in values(module.template-aio-server[each.key].interfaces) :
#     try(cidrhost(interface.prefix, each.value.netnum), null)
#     if lookup(interface, "enable_netnum", false)
#   ])))
#   libvirt_ca = module.hypervisor-common.ca.libvirt
# }
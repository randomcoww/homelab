# module "ssh-common" {
#   source = "./modules/ssh_common"
# }

# module "ignition-ssh-server" {
#   for_each = {
#     for host_key in [
#       "aio-0",
#       "store-0",
#     ] :
#     host_key => local.hosts[host_key]
#   }

#   source     = "./modules/ssh_server"
#   key_id     = each.value.hostname
#   user_names = [local.users.admin.name]
#   valid_principals = compact(concat([each.value.hostname, "127.0.0.1"], flatten([
#     for interface in values(module.template-aio-server[each.key].interfaces) :
#     try(cidrhost(interface.prefix, each.value.netnum), null)
#     if lookup(interface, "enable_netnum", false)
#   ])))
#   ssh_ca = module.ssh-common.ca.ssh
# }

# module "ssh-client" {
#   source = "./modules/ssh_client"

#   key_id                = var.ssh_client.key_id
#   public_key_openssh    = var.ssh_client.public_key
#   early_renewal_hours   = var.ssh_client.early_renewal_hours
#   validity_period_hours = var.ssh_client.validity_period_hours
#   valid_principals      = []
#   ssh_ca = module.ssh-common.ca.ssh
# }

# # sign ssh key
# output "ssh_client_cert_authorized_key" {
#   value = module.ssh-client.ssh_client_cert_authorized_key
# }
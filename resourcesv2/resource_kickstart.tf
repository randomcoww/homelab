# module "desktop-common" {
#   source = "../modulesv2/desktop_common"

#   user                 = var.desktop_user
#   password             = var.desktop_password
#   local_timezone       = var.desktop_timezone
#   internal_ca_cert_pem = tls_self_signed_cert.internal-ca.cert_pem
#   mtu                  = local.mtu
#   networks             = local.networks

#   # Desktop host KS
#   desktop_hosts = {
#     for k in keys(local.hosts) :
#     k => merge(local.hosts[k], {
#       host_network = {
#         for n in local.hosts[k].network :
#         lookup(n, "alias", lookup(n, "network", "placeholder")) => n
#       }
#     })
#     if contains(local.hosts[k].components, "desktop")
#   }
# }

# # Build and test environment
# module "kickstart-local" {
#   source = "../modulesv2/kickstart"

#   desktop_params = module.desktop-common.desktop_params
#   renderer       = local.local_renderer
# }
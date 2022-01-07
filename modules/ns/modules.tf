module "template-ssh_server" {
  source     = "../../modules/ssh_server"
  key_id     = var.hostname
  user_names = [var.user.name]
  valid_principals = compact(concat([var.hostname, "127.0.0.1"], flatten([
    for interface in values(local.interfaces) :
    try(cidrhost(interface.prefix, var.netnums.host), null)
  ])))
  ssh_ca = var.ssh_ca
}
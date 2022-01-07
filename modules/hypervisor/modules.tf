module "template-ssh_server" {
  source     = "../../modules/ssh_server"
  key_id     = var.hostname
  user_names = [local.user.name]
  valid_principals = compact(concat([var.hostname, "127.0.0.1"], flatten([
    for hardware_interface in values(local.hardware_interfaces) :
    [
      for interface in values(hardware_interface.interfaces) :
      try(cidrhost(interface.prefix, hardware_interface.netnum), null)
    ]
  ])))
  ssh_ca = var.ssh_ca
}
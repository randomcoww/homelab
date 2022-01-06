module "template-ssh_server" {
  source = "../../modules/ssh_server"
  key_id = var.hostname
  users = [
    var.user
  ]
  valid_principals = compact(concat([var.hostname, "127.0.0.1"], flatten([
    for interface in values(local.hardware_interfaces) :
    [
      for network in values(interface.networks) :
      try(cidrhost(network.prefix, network.tap.netnum), null)
    ]
  ])))
  ssh_ca = var.ssh_ca
}
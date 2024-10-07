module "desktop-environment" {
  for_each = local.members.desktop-environment
  source   = "./modules/desktop_environment"

  ignition_version = local.ignition_version
}

# Wireguard VPN client

module "wireguard-client" {
  for_each = local.members.wireguard-client
  source   = "./modules/wireguard_client"

  ignition_version    = local.ignition_version
  fw_mark             = local.fw_marks.wireguard
  private_key         = var.wireguard_client.private_key
  public_key          = var.wireguard_client.public_key
  address             = var.wireguard_client.address
  endpoint            = var.wireguard_client.endpoint
  allowed_ips         = var.wireguard_client.allowed_ips
  uid                 = local.users.client.uid
  table_priority_base = 32700
}
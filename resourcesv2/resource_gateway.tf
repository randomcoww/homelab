locals {
  gateway_hosts = {
    gateway-0 = {
      network = {
        store_ip = "192.168.127.217"
        store_if = "eth0"
        lan_ip   = "192.168.127.217"
        lan_if   = "eth1"
        sync_ip  = "192.168.127.217"
        sync_if  = "eth2"
        wan_ip   = "192.168.127.217"
        wan_if   = "eth3"
        vwan_ip  = "192.168.127.217"
        vwan_if  = "eth4"
        int_mac  = "52-54-00-1a-61-2a"
      }
      kea_ha_role = "primary"
    }
    gateway-1 = {
      network = {
        store_ip = "192.168.127.218"
        store_if = "eth0"
        lan_ip   = "192.168.127.218"
        lan_if   = "eth1"
        sync_ip  = "192.168.127.218"
        sync_if  = "eth2"
        wan_ip   = "192.168.127.218"
        wan_if   = "eth3"
        vwan_ip  = "192.168.127.218"
        vwan_if  = "eth4"
        int_mac  = "52-54-00-1a-61-2b"
      }
      kea_ha_role = "standby"
    }
  }
}

# Do this to each provider until for_each module is available
module "gateway-test" {
  source = "../modulesv2/gateway"

  user              = local.user
  ssh_ca_public_key = tls_private_key.ssh-ca.public_key_openssh
  mtu               = local.mtu
  networks          = local.networks
  services          = local.services
  domains           = local.domains
  container_images  = local.container_images
  gateway_hosts     = local.gateway_hosts

  # Render to one of KVM host matchbox instances
  renderer = local.renderers[var.renderer]
}
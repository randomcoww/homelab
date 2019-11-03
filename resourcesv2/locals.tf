locals {
  user = "core"
  mtu  = 9000

  local_renderer = {
    endpoint        = "127.0.0.1:8081"
    cert_pem        = module.renderer.matchbox_cert_pem
    private_key_pem = module.renderer.matchbox_private_key_pem
    ca_pem          = module.renderer.matchbox_ca_pem
  }

  service_ports = {
    renderer_http = 8080
    renderer_rpc  = 8081
  }

  networks = {
    store = {
      id        = 0
      network   = "192.168.126.0"
      cidr      = 23
      dhcp_pool = "192.168.127.64/26"
      if        = "en-store"
    }
    lan = {
      id        = 60
      network   = "192.168.62.0"
      cidr      = 23
      dhcp_pool = "192.168.63.64/26"
      if        = "en-lan"
    }
    # conntrack sync for provisioners
    sync = {
      id      = 90
      network = "192.168.190.0"
      cidr    = 29
      if      = "en-sync"
    }
    wan = {
      id = 30
      if = "en-wan"
    }
    # internal network on each hypervisor
    # ip is same on every host
    int = {
      network   = "192.168.224.0"
      cidr      = 23
      dhcp_pool = "192.168.225.64/26"
      if        = "en-int"
      ip        = "192.168.224.1"
    }
    metallb = {
      dhcp_pool = "192.168.126.64/26"
    }
  }
}

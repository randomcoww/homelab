module "kickstart" {
  source = "../modulesv2/kickstart"

  user              = local.user
  password          = var.password
  ssh_ca_public_key = tls_private_key.ssh-ca.public_key_openssh
  mtu               = local.mtu
  networks          = local.networks
  services          = local.services

  # LiveOS base KS
  live_hosts = {
    live-base = {
    }
  }

  # KVM host KS
  kvm_hosts = {
    kvm-0 = {
      network = {
        hw_if       = "enp1s0f0"
        host_tap_ip = "192.168.127.251"
        int_tap_ip  = local.services.renderer.vip
      }
    }
    kvm-1 = {
      network = {
        hw_if       = "enp1s0f0"
        host_tap_ip = "192.168.127.252"
        int_tap_ip  = local.services.renderer.vip
      }
    }
  }

  # Desktop host KS
  desktop_hosts = {
    desktop-0 = {
      network = {
        store_if = "eno2"
        store_ip = "192.168.127.253"
      }
      persistent_home_path = "/localhome"
      persistent_home_dev  = "/dev/disk/by-path/pci-0000:04:00.0-nvme-1-part1"
    }
  }

  # only local renderer makes sense here
  # this resource creates non-local renderers
  renderer = local.local_renderer
}

locals {
  renderers = {
    for k in keys(module.kickstart.matchbox_rpc_endpoints) :
    k => {
      endpoint        = module.kickstart.matchbox_rpc_endpoints[k]
      cert_pem        = module.kickstart.matchbox_cert_pem
      private_key_pem = module.kickstart.matchbox_private_key_pem
      ca_pem          = module.kickstart.matchbox_ca_pem
    }
  }
}
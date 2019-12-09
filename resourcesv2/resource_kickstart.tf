module "kickstart" {
  source = "../modulesv2/kickstart"

  user                 = local.user
  desktop_user         = var.desktop_user
  desktop_password     = var.desktop_password
  ssh_ca_public_key    = tls_private_key.ssh-ca.public_key_openssh
  internal_ca_cert_pem = tls_self_signed_cert.internal-ca.cert_pem
  mtu                  = local.mtu
  networks             = local.networks
  services             = local.services

  # LiveOS base KS
  live_hosts = {
    live-base = {
    }
  }

  # KVM host KS
  kvm_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "kvm")
  }

  # Desktop host KS
  desktop_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "desktop")
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

  libvirt = {
    for k in keys(module.kickstart.libvirt_endpoints) :
    k => {
      endpoint = module.kickstart.libvirt_endpoints[k]
    }
  }
}
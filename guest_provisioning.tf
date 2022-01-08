locals {
  # assign guests to hypervisor
  hypervisor_guest_preprocess = {
    hypervisor-0 = {
      guests = {
        gateway-0 = {
          vcpu   = 1
          memory = 512
          # pxeboot_macaddress = <assigned>
          interfaces = {
            internal = {
              hypervisor_interface_name = "internal"
            }
            lan = {
              hypervisor_interface_name = "phy0-lan"
            }
            sync = {
              hypervisor_interface_name = "phy0-sync"
            }
            wan = {
              hypervisor_interface_name = "phy0-wan"
            }
          }
        }
        ns-0 = {
          vcpu   = 1
          memory = 512
          # pxeboot_macaddress = <assigned>
          interfaces = {
            internal = {
              hypervisor_interface_name = "internal"
            }
            lan = {
              hypervisor_interface_name = "phy0-lan"
            }
          }
        }
        ns-1 = {
          vcpu   = 1
          memory = 512
          # pxeboot_macaddress = <assigned>
          interfaces = {
            internal = {
              hypervisor_interface_name = "internal"
            }
            lan = {
              hypervisor_interface_name = "phy0-lan"
            }
          }
        }
      }
    }
  }
}

module "matchbox_hypervisor-0" {
  source = "./modules/matchbox"
  endpoint = {
    endpoint        = local.hypervisor_endpoints.hypervisor-0.matchbox_rpc_endpoint
    cert_pem        = tls_locally_signed_cert.matchbox-client.cert_pem
    private_key_pem = tls_private_key.matchbox-client.private_key_pem
    ca_pem          = tls_self_signed_cert.matchbox-ca.cert_pem
  }
  # cannot configure module as for_each when sneding provider config
  hosts = {
    for guest_name, guest in local.hypervisor_guest_config.hypervisor-0.guests :
    guest_name => {
      kernel = "/assets/vmlinuz"
      initrd = ["/assets/initrd.img"]
      args = [
        "console=hvc0",
        "rd.neednet=1",
        "ignition.firstboot",
        "ignition.platform.id=metal",
        "systemd.unified_cgroup_hierarchy=0",
        "systemd.unit=multi-user.target",
        "elevator=noop",
        "initrd=initrd.img",
        "ignition.config.url=${local.hypervisor_endpoints.hypervisor-0.matchbox_http_endpoint}/ignition?mac=$${mac:hexhyp}",
        "coreos.live.rootfs_url=${local.hypervisor_endpoints.hypervisor-0.matchbox_http_endpoint}/assets/rootfs.img",
        "ip=${local.guest_ignition_config[guest_name].guest_interface}:dhcp",
      ]
      raw_ignition       = local.guest_ignition_config[guest_name].ignition
      pxeboot_macaddress = guest.pxeboot_macaddress
    }
  }
}

module "libvirt-domains_hypervisor-0" {
  source = "./modules/libvirt_domain"
  endpoint = {
    endpoint        = local.hypervisor_endpoints.hypervisor-0.libvirt_endpoint
    cert_pem        = tls_locally_signed_cert.libvirt-client.cert_pem
    private_key_pem = tls_private_key.libvirt-client.private_key_pem
    ca_pem          = tls_self_signed_cert.libvirt-ca.cert_pem
  }
  # cannot configure module as for_each when sneding provider config
  hosts = {
    for guest_name, guest in local.hypervisor_guest_config.hypervisor-0.guests :
    guest_name => {
      vcpu               = guest.vcpu
      memory             = guest.memory
      pxeboot_macaddress = guest.pxeboot_macaddress
      pxeboot_interface  = local.hypervisor_hostclass_config.internal_interface.interface_name
      interface_devices  = guest.interfaces
      system_image_tag   = local.config.system_image_tags.server
    }
  }
}
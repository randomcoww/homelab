locals {
  base_hosts = {
    gw-0 = {
      users = [
        "admin",
      ]
      netnum = 1
      hardware_interfaces = {
        phy0 = {
          mac   = "1c-83-41-30-e2-23"
          mtu   = 9000
          vlans = ["sync", "etcd", "service", "kubernetes", "wan"]
        }
        wlan0 = {
          mac          = "a8-7e-ea-c5-3f-46"
          mtu          = 9000
          enable_4addr = true
        }
      }
      bridge_interfaces = {
        br-lan = {
          interfaces = ["phy0", "wlan0"]
          mtu        = 9000
        }
      }
      tap_interfaces = {
        lan = {
          source_interface_name = "br-lan"
          enable_netnum         = true
        }
        sync = {
          source_interface_name = "phy0-sync"
          enable_netnum         = true
        }
        etcd = {
          source_interface_name = "phy0-etcd"
          enable_netnum         = true
        }
        service = {
          source_interface_name = "phy0-service"
          enable_netnum         = true
        }
        kubernetes = {
          source_interface_name = "phy0-kubernetes"
          enable_netnum         = true
        }
        wan = {
          source_interface_name = "phy0-wan"
          enable_dhcp           = true
          mac                   = "52-54-00-63-6e-b3"
        }
      }
      disks = {
        pv = {
          device = "/dev/disk/by-id/nvme-VICKTER_NVME_SSD_WLN020A01247"
          partitions = [
            {
              mount_path = local.pv_mount_path
              wipe       = false
            },
          ]
        }
      }
      container_storage_path = "${local.pv_mount_path}/containers"
      local_provisioner_path = "${local.pv_mount_path}/local_path_provisioner"
    }

    gw-1 = {
      users = [
        "admin",
      ]
      netnum = 3
      hardware_interfaces = {
        phy0 = {
          mac   = "1c-83-41-30-e2-54"
          mtu   = 9000
          vlans = ["sync", "etcd", "service", "kubernetes", "wan"]
        }
        wlan0 = {
          mac          = "fc-b3-bc-dc-4e-fc"
          mtu          = 9000
          enable_4addr = true
        }
      }
      bridge_interfaces = {
        br-lan = {
          interfaces = ["phy0", "wlan0"]
          mtu        = 9000
        }
      }
      tap_interfaces = {
        lan = {
          source_interface_name = "br-lan"
          enable_netnum         = true
        }
        sync = {
          source_interface_name = "phy0-sync"
          enable_netnum         = true
        }
        etcd = {
          source_interface_name = "phy0-etcd"
          enable_netnum         = true
        }
        service = {
          source_interface_name = "phy0-service"
          enable_netnum         = true
        }
        kubernetes = {
          source_interface_name = "phy0-kubernetes"
          enable_netnum         = true
        }
        wan = {
          source_interface_name = "phy0-wan"
          enable_dhcp           = true
          mac                   = "52-54-00-63-6e-b3"
        }
      }
      disks = {
        pv = {
          device = "/dev/disk/by-id/nvme-VICKTER_NVME_SSD_WLN020A01227"
          partitions = [
            {
              mount_path = local.pv_mount_path
              wipe       = false
            },
          ]
        }
      }
      container_storage_path = "${local.pv_mount_path}/containers"
      local_provisioner_path = "${local.pv_mount_path}/local_path_provisioner"
    }

    q-0 = {
      users = [
        "admin",
      ]
      netnum = 5
      hardware_interfaces = {
        phy0 = {
          mac   = "1c-83-41-30-bd-6f"
          mtu   = 9000
          vlans = ["etcd", "service", "kubernetes"]
        }
        wlan0 = {
          mac          = "8c-55-4a-d0-b1-2d"
          mtu          = 9000
          enable_4addr = true
        }
      }
      bridge_interfaces = {
        br-lan = {
          interfaces = ["phy0", "wlan0"]
          mtu        = 9000
        }
      }
      tap_interfaces = {
        lan = {
          source_interface_name = "br-lan"
          enable_dhcp           = true
          enable_netnum         = true
        }
        etcd = {
          source_interface_name = "phy0-etcd"
          enable_netnum         = true
        }
        service = {
          source_interface_name = "phy0-service"
          enable_netnum         = true
        }
        kubernetes = {
          source_interface_name = "phy0-kubernetes"
          enable_netnum         = true
        }
      }
      disks = {
        pv = {
          device = "/dev/disk/by-id/nvme-VICKTER_NVME_SSD_WLN020A00286"
          partitions = [
            {
              mount_path = local.pv_mount_path
              wipe       = false
            },
          ]
        }
      }
      container_storage_path = "${local.pv_mount_path}/containers"
      local_provisioner_path = "${local.pv_mount_path}/local_path_provisioner"
    }

    re-0 = {
      hostname = "remote"
      # not needed
      netnum = 0
      users = [
        "client",
      ]
      hardware_interfaces = {
        phy0 = {
          mac = "84-a9-38-0f-aa-76"
          mtu = 9000
        }
        wlan0 = {
          mac = "b4-b5-b6-74-79-15"
          mtu = 9000
        }
      }
      bridge_interfaces = {}
      tap_interfaces = {
        lan = {
          source_interface_name = "phy0"
          enable_dhcp           = true
        }
      }
      disks = {
        pv = {
          device = "/dev/disk/by-id/nvme-SKHynix_HFS512GDE9X084N_CYA8N037413008I5H"
          partitions = [
            {
              mount_path = local.pv_mount_path
              wipe       = false
            },
          ]
        }
      }
      container_storage_path = "${local.pv_mount_path}/containers"
    }

    de-1 = {
      netnum = 8
      users = [
        "client",
      ]
      hardware_interfaces = {
        phy0 = {
          mac           = "52-54-00-1a-61-1a"
          enable_dhcp   = true
          enable_netnum = true
          enable_arp    = true
          enable_mdns   = true
          mtu           = 9000
        }
      }
      bridge_interfaces = {}
      tap_interfaces    = {}
      disks = {
        pv = {
          device = "/dev/sda"
          partitions = [
            {
              mount_path = local.pv_mount_path
              wipe       = false
            },
          ]
        }
      }
      container_storage_path = "${local.pv_mount_path}/containers"
    }
  }

  base_members = {
    base              = ["gw-0", "gw-1", "q-0", "de-1", "re-0"]
    systemd-networkd  = ["gw-0", "gw-1", "q-0", "de-1", "re-0"]
    kubelet-base      = ["gw-0", "gw-1", "q-0"]
    gateway           = ["gw-0", "gw-1"]
    vrrp              = ["gw-0", "gw-1", "q-0"]
    disks             = ["gw-0", "gw-1", "q-0", "de-1", "re-0"]
    ssh-server        = ["gw-0", "gw-1", "q-0"]
    desktop           = ["de-1", "re-0"]
    etcd              = ["gw-0", "gw-1", "q-0"]
    kubernetes-master = ["gw-0", "gw-1"]
    kubernetes-worker = ["gw-0", "gw-1", "q-0"]
  }

  host_roles = transpose(local.base_members)
  hosts = {
    for host_key, host in local.base_hosts :
    host_key => merge({
      hostname = "${host_key}.${local.domains.internal_mdns}"
      }, host, {
      kubernetes_worker_labels = merge(
        {
          for role in lookup(local.host_roles, host_key, []) :
          "role-${role}" => "true"
        },
        lookup(host, "kubernetes_worker_labels", {}),
      )
    })
  }

  # use this instead of base_members #
  members = {
    for key, members in local.base_members :
    key => {
      for host_key in members :
      host_key => local.hosts[host_key]
    }
  }
}
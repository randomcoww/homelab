locals {
  base_hosts = {
    gw-0 = {
      users = [
        "admin"
      ]
      vrrp_netnum = 2
      netnum      = 1
      hardware_interfaces = {
        phy0 = {
          mac   = "1c-83-41-30-e2-23"
          mtu   = 9000
          vlans = ["sync", "etcd", "service", "wan"]
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
          enable_mdns           = true
          enable_netnum         = true
          enable_vrrp_netnum    = true
          enable_dhcp_server    = true
          mtu                   = 9000
        }
        sync = {
          source_interface_name = "phy0-sync"
          enable_netnum         = true
          mtu                   = 9000
        }
        etcd = {
          source_interface_name = "phy0-etcd"
          enable_netnum         = true
          mtu                   = 9000
        }
        service = {
          source_interface_name = "phy0-service"
          enable_netnum         = true
          mtu                   = 9000
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
        "admin"
      ]
      vrrp_netnum = 2
      netnum      = 3
      hardware_interfaces = {
        phy0 = {
          mac   = "1c-83-41-30-e2-54"
          mtu   = 9000
          vlans = ["sync", "etcd", "service", "wan"]
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
          enable_mdns           = true
          enable_netnum         = true
          enable_vrrp_netnum    = true
          enable_dhcp_server    = true
          mtu                   = 9000
        }
        sync = {
          source_interface_name = "phy0-sync"
          enable_netnum         = true
          mtu                   = 9000
        }
        etcd = {
          source_interface_name = "phy0-etcd"
          enable_netnum         = true
          mtu                   = 9000
        }
        service = {
          source_interface_name = "phy0-service"
          enable_netnum         = true
          mtu                   = 9000
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

    de-0 = {
      users = [
        "client"
      ]
      netnum = 4
      hardware_interfaces = {
        phy0 = {
          mac   = "84-a9-38-0f-aa-76"
          mtu   = 9000
          vlans = ["etcd", "service"]
        }
        wlan0 = {
          mac = "b4-b5-b6-74-79-15"
          mtu = 9000
        }
      }
      bridge_interfaces = {
        br-lan = {
          interfaces = ["phy0"]
          mtu        = 9000
        }
      }
      tap_interfaces = {
        lan = {
          source_interface_name = "br-lan"
          enable_mdns           = true
          enable_netnum         = true
          enable_dhcp           = true
          mtu                   = 9000
        }
        etcd = {
          source_interface_name = "phy0-etcd"
          enable_netnum         = true
          mtu                   = 9000
        }
        service = {
          source_interface_name = "phy0-service"
          enable_netnum         = true
          mtu                   = 9000
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
      local_provisioner_path = "${local.pv_mount_path}/local_path_provisioner"
      kubernetes_worker_taints = [
        {
          key    = "node.kubernetes.io/unschedulable"
          effect = "NoExecute"
          value  = "true"
        }
      ]
      kubernetes_worker_labels = {
        "nvidia.com/gpu" = "true"
      }
    }

    re-0 = {
      users = [
        "client"
      ]
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
  }

  base_members = {
    base              = ["gw-0", "gw-1", "de-0", "re-0"]
    systemd-networkd  = ["gw-0", "gw-1", "de-0"]
    kubelet-base      = ["gw-0", "gw-1", "de-0"]
    gateway           = ["gw-0", "gw-1"]
    disks             = ["gw-0", "gw-1", "de-0", "re-0"]
    ssh-server        = ["gw-0", "gw-1"]
    desktop           = ["de-0", "re-0"]
    etcd              = ["gw-0", "gw-1", "de-0"]
    kubernetes-master = ["gw-0", "gw-1"]
    kubernetes-worker = ["gw-0", "gw-1", "de-0"]
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
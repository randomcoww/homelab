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
      }
      wlan_interfaces = {
      }
      bridge_interfaces = {
      }
      tap_interfaces = {
        lan = {
          source_interface_name = "phy0"
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
        }
      }
      disks = {
        pv = {
          device = "/dev/disk/by-id/nvme-VICKTER_NVME_SSD_WLN020A01247"
          partitions = [
            {
              mount_path = local.mounts.containers_path
              format     = "xfs"
              wipe       = false
              options    = ["-s", "size=4096"]
            },
          ]
        }
      }
      persistent_path = local.mounts.containers_path
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
      }
      wlan_interfaces = {
      }
      bridge_interfaces = {
      }
      tap_interfaces = {
        lan = {
          source_interface_name = "phy0"
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
        }
      }
      disks = {
        pv = {
          device = "/dev/disk/by-id/nvme-VICKTER_NVME_SSD_WLN020A01227"
          partitions = [
            {
              mount_path = local.mounts.containers_path
              format     = "xfs"
              wipe       = false
              options    = ["-s", "size=4096"]
            },
          ]
        }
      }
      persistent_path = local.mounts.containers_path
    }

    q-0 = {
      users = [
        "admin",
        "client",
      ]
      netnum = 5
      hardware_interfaces = {
        phy0 = {
          mac   = "1c-83-41-30-bd-6f"
          mtu   = 9000
          vlans = ["sync", "etcd", "service", "kubernetes", "wan"]
        }
      }
      wlan_interfaces = {
      }
      bridge_interfaces = {
      }
      tap_interfaces = {
        lan = {
          source_interface_name = "phy0"
          enable_netnum         = true
        }
        sync = {
          source_interface_name = "phy0-sync"
          enable_netnum         = false
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
        }
      }
      disks = {
        pv = {
          device = "/dev/disk/by-id/nvme-VICKTER_NVME_SSD_WLN020A00286"
          partitions = [
            {
              mount_path = local.mounts.containers_path
              format     = "xfs"
              wipe       = false
              options    = ["-s", "size=4096"]
            },
          ]
        }
      }
      persistent_path = local.mounts.containers_path
    }

    de-0 = {
      netnum = 8
      users = [
        "client",
      ]
      hardware_interfaces = {
        phy0 = {
          mac   = "58-47-ca-71-4d-ce"
          mtu   = 9000
          vlans = ["service", "kubernetes"]
        }
        # mobile
        phy1 = {
          mac = "32-57-14-7a-aa-10"
        }
      }
      wlan_interfaces = {
        wlan0 = {
          mac         = "10-6f-d9-cf-d5-71"
          enable_dhcp = true
          enable_mdns = true
          metric      = 2048
        }
      }
      bridge_interfaces = {
        br-lan = {
          interfaces = ["phy0"]
        }
      }
      tap_interfaces = {
        lan = {
          source_interface_name = "br-lan"
          enable_dhcp           = true
        }
        service = {
          source_interface_name = "phy0-service"
          enable_netnum         = true
        }
        kubernetes = {
          source_interface_name = "phy0-kubernetes"
          enable_netnum         = true
        }
        fallback = {
          source_interface_name = "phy1"
          enable_dhcp           = true
        }
      }
      disks = {
        pv = {
          device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S6S1NS0W106465F"
          partitions = [
            {
              mount_path = local.mounts.home_path
              format     = "xfs"
              wipe       = false
              options    = ["-s", "size=4096"]
            },
          ]
        }
      }
      persistent_path = local.mounts.home_path
      kubernetes_worker_taints = [
        {
          key    = "node-role.kubernetes.io/de"
          effect = "NoSchedule"
        },
        {
          key    = "node-role.kubernetes.io/de"
          effect = "NoExecute"
        },
      ]
    }
  }

  base_members = {
    base              = ["gw-0", "gw-1", "q-0", "de-0"]
    systemd-networkd  = ["gw-0", "gw-1", "q-0", "de-0"]
    network-manager   = []
    kubelet-base      = ["gw-0", "gw-1", "q-0", "de-0"]
    gateway           = ["gw-0", "gw-1", "q-0"]
    vrrp              = ["gw-0", "gw-1"]
    disks             = ["gw-0", "gw-1", "q-0", "de-0"]
    ssh-server        = ["gw-0", "gw-1", "q-0"]
    etcd              = ["gw-0", "gw-1", "q-0"]
    kubernetes-master = ["gw-0", "gw-1"]
    kubernetes-worker = ["gw-0", "gw-1", "q-0", "de-0"]
    desktop           = ["de-0"]
  }

  hosts = {
    for host_key, host in local.base_hosts :
    host_key => merge({
      hostname = "${host_key}.${local.domains.internal_mdns}"
    }, host)
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

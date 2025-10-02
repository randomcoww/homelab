locals {
  base_hosts = {
    k-0 = {
      netnum = 1
      physical_interfaces = {
        phy0 = {
          match_mac = "b0-41-6f-16-a2-dc"
          # match_mac = "b0-41-6f-16-a2-dd"
          mtu = local.default_mtu
        }
      }
      vlan_interfaces = {
        phy0-node = {
          source  = "phy0"
          network = "node"
        }
        phy0-sync = {
          source  = "phy0"
          network = "sync"
        }
        phy0-service = {
          source  = "phy0"
          network = "service"
        }
        phy0-etcd = {
          source  = "phy0"
          network = "etcd"
        }
        phy0-wan = {
          source  = "phy0"
          network = "wan"
          mac     = "52-54-00-63-6e-b3"
        }
        phy0-backup = {
          source  = "phy0"
          network = "backup"
          mac     = "52-54-00-63-6e-b4"
        }
      }
      networks = {
        lan = {
          interface     = "phy0"
          enable_netnum = true
        }
        node = {
          interface     = "phy0-node"
          enable_netnum = true
        }
        sync = {
          interface     = "phy0-sync"
          enable_netnum = true
        }
        service = {
          interface     = "phy0-service"
          enable_netnum = true
        }
        etcd = {
          interface     = "phy0-etcd"
          enable_netnum = true
        }
        wan = {
          interface   = "phy0-wan"
          enable_dhcp = true
        }
        backup = {
          interface     = "phy0-backup"
          enable_dhcp   = true
          enable_dns    = false
          enable_routes = false
          metric        = 4096
        }
      }
      disks = {
        pv = {
          wipe   = false
          device = "/dev/nvme0n1"
          partitions = [
            {
              mount_path = local.kubernetes.containers_path
              format     = "xfs"
              wipe       = false
              options    = ["-s", "size=4096"]
            },
          ]
        }
      }
      network_boot = {
        interface = "phy0"
        image     = local.pxeboot_image_set.coreos
        boot_args = [
          "selinux=0",
        ]
      }
      kubernetes_node_labels = {
      }
    }

    k-1 = {
      netnum = 3
      physical_interfaces = {
        phy0 = {
          match_mac = "b0-41-6f-16-f9-88"
          # match_mac = "b0-41-6f-16-f9-89"
          mtu = local.default_mtu
        }
      }
      vlan_interfaces = {
        phy0-node = {
          source  = "phy0"
          network = "node"
        }
        phy0-sync = {
          source  = "phy0"
          network = "sync"
        }
        phy0-service = {
          source  = "phy0"
          network = "service"
        }
        phy0-etcd = {
          source  = "phy0"
          network = "etcd"
        }
        phy0-wan = {
          source  = "phy0"
          network = "wan"
          mac     = "52-54-00-63-6e-b3"
        }
        phy0-backup = {
          source  = "phy0"
          network = "backup"
          mac     = "52-54-00-63-6e-b4"
        }
      }
      networks = {
        lan = {
          interface     = "phy0"
          enable_netnum = true
        }
        node = {
          interface     = "phy0-node"
          enable_netnum = true
        }
        sync = {
          interface     = "phy0-sync"
          enable_netnum = true
        }
        service = {
          interface     = "phy0-service"
          enable_netnum = true
        }
        etcd = {
          interface     = "phy0-etcd"
          enable_netnum = true
        }
        wan = {
          interface   = "phy0-wan"
          enable_dhcp = true
        }
        backup = {
          interface     = "phy0-backup"
          enable_dhcp   = true
          enable_dns    = false
          enable_routes = false
          metric        = 4096
        }
      }
      disks = {
        pv = {
          wipe   = false
          device = "/dev/nvme0n1"
          partitions = [
            {
              mount_path = local.kubernetes.containers_path
              format     = "xfs"
              wipe       = false
              options    = ["-s", "size=4096"]
            },
          ]
        }
      }
      network_boot = {
        interface = "phy0"
        image     = local.pxeboot_image_set.coreos
        boot_args = [
          "selinux=0",
        ]
      }
      kubernetes_node_labels = {
      }
    }

    k-2 = {
      netnum = 5
      physical_interfaces = {
        phy0 = {
          match_mac = "b0-41-6f-16-9e-76"
          # match_mac = "b0-41-6f-16-9e-77"
          mtu = local.default_mtu
        }
      }
      vlan_interfaces = {
        phy0-node = {
          source  = "phy0"
          network = "node"
        }
        phy0-service = {
          source  = "phy0"
          network = "service"
        }
        phy0-etcd = {
          source  = "phy0"
          network = "etcd"
        }
      }
      networks = {
        lan = {
          interface     = "phy0"
          enable_netnum = true
        }
        node = {
          interface     = "phy0-node"
          enable_netnum = true
        }
        service = {
          interface     = "phy0-service"
          enable_netnum = true
        }
        etcd = {
          interface     = "phy0-etcd"
          enable_netnum = true
        }
      }
      disks = {
        pv = {
          wipe   = false
          device = "/dev/nvme0n1"
          partitions = [
            {
              mount_path = local.kubernetes.containers_path
              format     = "xfs"
              wipe       = false
              options    = ["-s", "size=4096"]
            },
          ]
        }
      }
      network_boot = {
        interface = "phy0"
        image     = local.pxeboot_image_set.coreos
        boot_args = [
          "selinux=0",
        ]
      }
      kubernetes_node_labels = {
      }
    }

    k-3 = {
      netnum = 6
      physical_interfaces = {
        phy0 = {
          match_mac = "74-56-3c-c3-10-68"
          mtu       = local.default_mtu
        }
        wlan0 = {
          match_mac = "7c-66-ef-f4-57-a8" # RTL8852CE
        }
      }
      vlan_interfaces = {
        phy0-node = {
          source  = "phy0"
          network = "node"
        }
        phy0-service = {
          source  = "phy0"
          network = "service"
        }
        phy0-etcd = {
          source  = "phy0"
          network = "etcd"
        }
      }
      bridge_interfaces = {
        br-lan = {
          sources = [
            "phy0",
          ]
        }
      }
      networks = {
        lan = {
          interface     = "br-lan"
          enable_netnum = true
        }
        node = {
          interface     = "phy0-node"
          enable_netnum = true
        }
        service = {
          interface     = "phy0-service"
          enable_netnum = true
        }
        etcd = {
          interface     = "phy0-etcd"
          enable_netnum = true
        }
      }
      disks = {
        pv = {
          wipe   = false
          device = "/dev/nvme0n1"
          partitions = [
            {
              mount_path = local.kubernetes.containers_path
              format     = "xfs"
              wipe       = false
              options    = ["-s", "size=4096"]
            },
          ]
        }
      }
      network_boot = {
        interface = "phy0"
        image     = local.pxeboot_image_set.coreos
        boot_args = [
          "selinux=0",
          ## stub all Nvidia GPUs
          # "vfio-pci.id=10de:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,10de:ffffffff:ffffffff:ffffffff:00040300:ffffffff",
          ## stub all AMD GPUs
          # "vfio-pci.id=1002:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,1002:ffffffff:ffffffff:ffffffff:00040300:ffffffff",
        ]
      }
      kubernetes_node_labels = {
        "hostapd" = true
      }
    }
  }

  base_members = {
    base              = ["k-0", "k-1", "k-2", "k-3"]
    systemd-networkd  = ["k-0", "k-1", "k-2", "k-3"]
    server            = ["k-0", "k-1", "k-2", "k-3"]
    disks             = ["k-0", "k-1", "k-2", "k-3"]
    upstream-dns      = ["k-0", "k-1", "k-2", "k-3"]
    gateway           = ["k-0", "k-1"]
    kubernetes-master = ["k-2", "k-3"]
    etcd              = ["k-0", "k-1", "k-2"]
    kubernetes-worker = ["k-0", "k-1", "k-2", "k-3"]
  }

  # finalized local vars #

  hosts = {
    for host_key, host in local.base_hosts :
    host_key => merge(host, {
      fqdn = "${host_key}.${local.domains.kubernetes}"
      networks = {
        for name, network in lookup(host, "networks", {}) :
        name => merge(local.networks[name], network)
      }
      wlan_networks = {
        for name, network in lookup(host, "wlan_networks", {}) :
        name => merge(local.networks[name], network)
      }

      physical_interfaces = lookup(host, "physical_interfaces", {})
      bridge_interfaces   = lookup(host, "bridge_interfaces", {})
      vlan_interfaces = {
        for name, interface in lookup(host, "vlan_interfaces", {}) :
        name => merge(interface, {
          vlan_id = local.networks[interface.network].vlan_id
        })
      }
      kubernetes_node_labels = merge(contains(local.base_members.kubernetes-master, host_key) ? {
        "node-role.kubernetes.io/control-plane" = true
      } : {}, lookup(host, "kubernetes_node_labels", {}))
    })
  }

  members = {
    for key, members in local.base_members :
    key => {
      for host_key in members :
      host_key => local.hosts[host_key]
    }
  }
}
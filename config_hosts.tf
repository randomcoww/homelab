locals {
  base_hosts = {
    k-0 = {
      host_image = local.host_images.default
      netnum     = 1
      physical_interfaces = {
        phy0 = {
          match_mac = "b0-41-6f-16-a2-dc"
          # match_mac = "b0-41-6f-16-a2-dd"
          mtu = local.default_mtu
        }
        wlan0 = {
          match_mac = "a8-59-5f-be-af-f0" # AX200
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
      bridge_interfaces = {
        br0 = {
          sources = [
            "phy0",
          ]
        }
      }
      networks = {
        lan = {
          interface     = "br0"
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
          interface = "phy0-wan"
        }
        backup = {
          interface     = "phy0-backup"
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
      boot_args = [
        "pcie_aspm=off", # TODO: remove if this gets fixed - workaround for r8169 transmit queue timed out issue
      ]
    }

    k-1 = {
      host_image = local.host_images.default
      netnum     = 3
      physical_interfaces = {
        phy0 = {
          match_mac = "b0-41-6f-16-f9-88"
          # match_mac = "b0-41-6f-16-f9-89"
          mtu = local.default_mtu
        }
        wlan0 = {
          match_mac = "ec-4c-8c-50-17-ed" # AX200
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
      bridge_interfaces = {
        br0 = {
          sources = [
            "phy0",
          ]
        }
      }
      networks = {
        lan = {
          interface     = "br0"
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
          interface = "phy0-wan"
        }
        backup = {
          interface     = "phy0-backup"
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
      boot_args = [
        "pcie_aspm=off", # TODO: remove if this gets fixed - workaround for r8169 transmit queue timed out issue
      ]
    }

    k-2 = {
      host_image = local.host_images.default
      netnum     = 5
      physical_interfaces = {
        phy0 = {
          match_mac = "b0-41-6f-16-9e-76"
          # match_mac = "b0-41-6f-16-9e-77"
          mtu = local.default_mtu
        }
        wlan0 = {
          match_mac = "a8-59-5f-98-b9-80" # AX200
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
        br0 = {
          sources = [
            "phy0",
          ]
        }
      }
      networks = {
        lan = {
          interface     = "br0"
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
      boot_args = [
        "pcie_aspm=off", # TODO: remove if this gets fixed - workaround for r8169 transmit queue timed out issue
      ]
    }

    k-3 = {
      host_image = local.host_images.default
      netnum     = 6
      physical_interfaces = {
        phy0 = {
          match_mac = "9c-bf-0d-01-0e-7b"
          mtu       = local.default_mtu
        }
        wlan0 = {
          match_mac = "dc-56-7b-03-4c-e5" # MT7925
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
        br0 = {
          sources = [
            "phy0",
          ]
        }
      }
      networks = {
        lan = {
          interface     = "br0"
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
      boot_args = [
        "pcie_aspm=off",               # TODO: remove if this gets fixed - workaround for r8169 transmit queue timed out issue
        "ttm.pages_limit=31457280",    # 120G https://community.frame.work/t/igpu-vram-how-much-can-be-assigned/73081
        "ttm.page_pool_size=24576000", # 96G preallocated
      ]
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
      match_macs = compact([
        for _, interface in lookup(host, "physical_interfaces", {}) :
        lookup(interface, "match_mac", "")
      ])
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
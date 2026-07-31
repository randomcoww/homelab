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
        phy-node = {
          source  = "phy0"
          network = "node"
        }
        phy-service = {
          source  = "phy0"
          network = "service"
        }
        phy-etcd = {
          source  = "phy0"
          network = "etcd"
        }
        phy-wan = {
          source  = "phy0"
          network = "wan"
          mac     = "52-54-00-63-6e-b3"
        }
      }
      networks = {
        lan = {
          interface = "phy0"
        }
        node = {
          interface = "phy-node"
        }
        service = {
          interface = "phy-service"
        }
        etcd = {
          interface = "phy-etcd"
        }
        wan = {
          interface = "phy-wan"
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
        "ttm.pages_limit=${32 * 512 * 512}",   # 32G
        "ttm.page_pool_size=${1 * 512 * 512}", # 1G preallocated
        "pcie_aspm=off",                       # TODO: workaround for r8169 transmit queue timed out issue
      ]
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
        phy-node = {
          source  = "phy0"
          network = "node"
        }
        phy-service = {
          source  = "phy0"
          network = "service"
        }
        phy-etcd = {
          source  = "phy0"
          network = "etcd"
        }
        phy-wan = {
          source  = "phy0"
          network = "wan"
          mac     = "52-54-00-63-6e-b3"
        }
      }
      networks = {
        lan = {
          interface = "phy0"
        }
        node = {
          interface = "phy-node"
        }
        service = {
          interface = "phy-service"
        }
        etcd = {
          interface = "phy-etcd"
        }
        wan = {
          interface = "phy-wan"
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
        "ttm.pages_limit=${32 * 512 * 512}",   # 32G
        "ttm.page_pool_size=${1 * 512 * 512}", # 1G preallocated
        "pcie_aspm=off",                       # TODO: workaround for r8169 transmit queue timed out issue
      ]
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
        phy-node = {
          source  = "phy0"
          network = "node"
        }
        phy-service = {
          source  = "phy0"
          network = "service"
        }
        phy-etcd = {
          source  = "phy0"
          network = "etcd"
        }
      }
      networks = {
        lan = {
          interface = "phy0"
        }
        node = {
          interface = "phy-node"
        }
        service = {
          interface = "phy-service"
        }
        etcd = {
          interface = "phy-etcd"
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
        "ttm.pages_limit=${32 * 512 * 512}",   # 32G
        "ttm.page_pool_size=${1 * 512 * 512}", # 1G preallocated
        "pcie_aspm=off",                       # TODO: workaround for r8169 transmit queue timed out issue
      ]
    }

    k-3 = {
      netnum = 6
      physical_interfaces = {
        phy0 = {
          match_mac = "9c-bf-0d-01-0e-7b"
          mtu       = local.default_mtu
        }
      }
      vlan_interfaces = {
        phy-node = {
          source  = "phy0"
          network = "node"
        }
        phy-service = {
          source  = "phy0"
          network = "service"
        }
        phy-etcd = {
          source  = "phy0"
          network = "etcd"
        }
      }
      networks = {
        lan = {
          interface = "phy0"
        }
        node = {
          interface = "phy-node"
        }
        service = {
          interface = "phy-service"
        }
        etcd = {
          interface = "phy-etcd"
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
        "ttm.pages_limit=${128 * 512 * 512}",   # 128G https://community.frame.work/t/igpu-vram-how-much-can-be-assigned/73081
        "ttm.page_pool_size=${96 * 512 * 512}", # 96G preallocated
        "pcie_aspm=off",                        # TODO: workaround for r8169 transmit queue timed out issue
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
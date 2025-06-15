locals {
  base_hosts = {
    gw-0 = {
      enable_rolling_reboot = true
      netnum                = 1
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
        image     = local.pxeboot_image_set.latest
        boot_args = [
          "selinux=0",
        ]
      }
      kubernetes_node_labels = {
      }
    }

    gw-1 = {
      enable_rolling_reboot = true
      netnum                = 3
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
        image     = local.pxeboot_image_set.latest
        boot_args = [
          "numa=off",
          "selinux=0",
          "mitigations=off",
        ]
      }
      kubernetes_node_labels = {
      }
    }

    q-0 = {
      enable_rolling_reboot = true
      netnum                = 5
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
        image     = local.pxeboot_image_set.latest
        boot_args = [
          "selinux=0",
        ]
      }
      kubernetes_node_labels = {
        "node-role.kubernetes.io/control-plane" = true
      }
    }

    de-1 = {
      enable_rolling_reboot = true
      netnum                = 6
      physical_interfaces = {
        phy0 = {
          match_mac = "74-56-3c-c3-10-68"
          mtu       = local.default_mtu
        }
        wlan0 = {
          # match_mac = "10-6f-d9-cf-d5-71" # MT7921
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
              mount_path = dirname(local.users.client.home_dir)
              format     = "xfs"
              wipe       = false
              options    = ["-s", "size=4096"]
              bind_mounts = [
                {
                  relative_path = "containers"
                  mount_path    = local.kubernetes.containers_path
                },
                {
                  relative_path = "tmp"
                  mount_path    = "/var/tmp"
                },
              ]
            },
          ]
        }
      }
      network_boot = {
        interface = "phy0"
        image     = local.pxeboot_image_set.latest
        boot_args = [
          "selinux=0",
          ## stub all Nvidia GPUs
          # "vfio-pci.id=10de:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,10de:ffffffff:ffffffff:ffffffff:00040300:ffffffff",
          ## stub all AMD GPUs
          # "vfio-pci.id=1002:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,1002:ffffffff:ffffffff:ffffffff:00040300:ffffffff",
        ]
      }
      kubernetes_node_labels = {
        "node-role.kubernetes.io/control-plane" = true
        "hostapd"                               = true
      }
    }
  }

  base_members = {
    base              = ["gw-0", "gw-1", "q-0", "de-1"]
    systemd-networkd  = ["gw-0", "gw-1", "q-0", "de-1"]
    server            = ["gw-0", "gw-1", "q-0", "de-1"]
    disks             = ["gw-0", "gw-1", "q-0", "de-1"]
    upstream-dns      = ["gw-0", "gw-1", "q-0", "de-1"]
    gateway           = ["gw-0", "gw-1"]
    kubernetes-master = ["q-0", "de-1"]
    etcd              = ["gw-0", "gw-1", "q-0"]
    kubernetes-worker = ["gw-0", "gw-1", "q-0", "de-1"]
    client            = ["de-1"]
  }

  # finalized local vars #

  hosts = {
    for host_key, host in local.base_hosts :
    host_key => merge(host, {
      hostname = "${host_key}.${local.domains.mdns}"
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
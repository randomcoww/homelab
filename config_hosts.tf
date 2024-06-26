locals {
  base_hosts = {
    gw-0 = {
      users = [
        "admin",
      ]
      netnum = 1
      physical_interfaces = {
        phy0 = {
          match_mac = "1c-83-41-30-e2-23"
          mtu       = local.default_mtu
        }
      }
      vlan_interfaces = {
        phy0-sync = {
          source  = "phy0"
          network = "sync"
        }
        phy0-etcd = {
          source  = "phy0"
          network = "etcd"
        }
        phy0-service = {
          source  = "phy0"
          network = "service"
        }
        phy0-kubernetes = {
          source  = "phy0"
          network = "kubernetes"
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
        sync = {
          interface     = "phy0-sync"
          enable_netnum = true
        }
        etcd = {
          interface     = "phy0-etcd"
          enable_netnum = true
        }
        service = {
          interface     = "phy0-service"
          enable_netnum = true
        }
        kubernetes = {
          interface     = "phy0-kubernetes"
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
      network_boot = {
        interface = "phy0"
        image     = local.pxeboot_image_set.coreos
        boot_args = [
          "numa=off",
          "systemd.unit=multi-user.target",
          "enforcing=0",
          "mitigations=off",
        ]
      }
      kubernetes_node_labels = {
        kea = true
      }
    }

    gw-1 = {
      users = [
        "admin",
      ]
      netnum = 3
      physical_interfaces = {
        phy0 = {
          match_mac = "1c-83-41-30-bd-6f"
          mtu       = local.default_mtu
        }
      }
      vlan_interfaces = {
        phy0-sync = {
          source  = "phy0"
          network = "sync"
        }
        phy0-etcd = {
          source  = "phy0"
          network = "etcd"
        }
        phy0-service = {
          source  = "phy0"
          network = "service"
        }
        phy0-kubernetes = {
          source  = "phy0"
          network = "kubernetes"
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
        sync = {
          interface     = "phy0-sync"
          enable_netnum = true
        }
        etcd = {
          interface     = "phy0-etcd"
          enable_netnum = true
        }
        service = {
          interface     = "phy0-service"
          enable_netnum = true
        }
        kubernetes = {
          interface     = "phy0-kubernetes"
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
      network_boot = {
        interface = "phy0"
        image     = local.pxeboot_image_set.coreos
        boot_args = [
          "numa=off",
          "systemd.unit=multi-user.target",
          "enforcing=0",
          "mitigations=off",
        ]
      }
      kubernetes_node_labels = {
        kea = true
      }
    }

    q-0 = {
      users = [
        "admin",
      ]
      netnum = 5
      physical_interfaces = {
        phy0 = {
          match_mac = "1c-83-41-30-e2-54"
          mtu       = local.default_mtu
        }
      }
      vlan_interfaces = {
        phy0-sync = {
          source  = "phy0"
          network = "sync"
        }
        phy0-etcd = {
          source  = "phy0"
          network = "etcd"
        }
        phy0-service = {
          source  = "phy0"
          network = "service"
        }
        phy0-kubernetes = {
          source  = "phy0"
          network = "kubernetes"
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
        sync = {
          interface     = "phy0-sync"
          enable_netnum = true
        }
        etcd = {
          interface     = "phy0-etcd"
          enable_netnum = true
        }
        service = {
          interface     = "phy0-service"
          enable_netnum = true
        }
        kubernetes = {
          interface     = "phy0-kubernetes"
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
      network_boot = {
        interface = "phy0"
        image     = local.pxeboot_image_set.coreos
        boot_args = [
          "numa=off",
          "systemd.unit=multi-user.target",
          "enforcing=0",
          "mitigations=off",
        ]
      }
      kubernetes_node_labels = {
        kea = true
      }
    }

    de-1 = {
      users = [
        "client",
      ]
      netnum = 6
      physical_interfaces = {
        phy0 = {
          match_mac = "74-56-3c-c3-10-68"
          mtu       = local.default_mtu
        }
        wlan0 = {
          match_mac = "10-6f-d9-cf-d5-71"
        }
        # backup WAN on mobile data
        wlan1 = {
          match_mac = "32-57-14-7a-aa-10"
        }
      }
      bridge_interfaces = {
        br-lan = {
          sources = [
            "phy0",
          ]
        }
      }
      vlan_interfaces = {
        phy0-service = {
          source  = "phy0"
          network = "service"
        }
        phy0-kubernetes = {
          source  = "phy0"
          network = "kubernetes"
        }
        phy0-wan = {
          source  = "phy0"
          network = "wan"
        }
      }
      networks = {
        lan = {
          interface   = "br-lan"
          enable_dhcp = true
        }
        service = {
          interface     = "phy0-service"
          enable_netnum = true
        }
        kubernetes = {
          interface     = "phy0-kubernetes"
          enable_netnum = true
        }
        mobile = {
          interface   = "wlan1"
          metric      = 512
          enable_dhcp = true
          enable_dns  = true
        }
        wan = {
          interface   = "phy0-wan"
          metric      = 4096
          enable_dhcp = true
        }
      }
      disks = {
        pv = {
          wipe   = false
          device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_2TB_S59CNM0W609225K"
          partitions = [
            {
              mount_path = local.mounts.home_path
              format     = "xfs"
              wipe       = false
              options    = ["-s", "size=4096"]
              bind_mounts = [
                {
                  relative_path = "containers"
                  mount_path    = local.mounts.containers_path
                },
              ]
            },
          ]
        }
      }
      network_boot = {
        interface = "phy0"
        image     = local.pxeboot_image_set.silverblue
        boot_args = [
          "iommu=pt",
          "amd_iommu=pt",
          "rd.driver.pre=vfio-pci",
          "numa=off",
          "enforcing=0",
          "rd.driver.blacklist=nouveau",
          "modprobe.blacklist=nouveau",
          "nvidia-drm.modeset=1",
          "nvidia.NVreg_OpenRmEnableUnsupportedGpus=1",
          ## stub all Nvidia GPUs
          # "vfio-pci.id=10de:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,10de:ffffffff:ffffffff:ffffffff:00040300:ffffffff",
          ## stub all AMD GPUs
          # "vfio-pci.id=1002:ffffffff:ffffffff:ffffffff:00030000:ffff00ff,1002:ffffffff:ffffffff:ffffffff:00040300:ffffffff",
        ]
      }
      kubernetes_node_labels = {
        hostapd = true
        nvidia  = true
      }
    }

    # remote site
    r-0 = {
      users = [
        "admin",
      ]
      netnum = 7
      physical_interfaces = {
        phy0 = {
          match_mac = "ec-21-e5-72-46-27"
          mtu       = local.default_mtu
        }
        wlan0 = {
          match_mac = "3e-b1-a0-f3-9b-34"
        }
      }
      networks = {
        lan = {
          interface   = "phy0"
          enable_dhcp = true
        }
      }
      disks = {
        pv = {
          wipe   = false
          device = "/dev/disk/by-id/scsi-SATA_SAMSUNG_MZNLN512_S2SWNX0HC04051"
          partitions = [
            {
              mount_path = local.mounts.home_path
              format     = "xfs"
              wipe       = false
              options    = ["-s", "size=4096"]
              bind_mounts = [
                {
                  relative_path = "containers"
                  mount_path    = local.mounts.containers_path
                },
              ]
            },
          ]
        }
      }
    }

    # chromebook
    de-0 = {
      users = [
        "client",
      ]
    }
  }

  base_members = {
    base                = ["gw-0", "gw-1", "q-0", "de-0", "de-1", "r-0"]
    systemd-networkd    = ["gw-0", "gw-1", "q-0", "de-1", "r-0"]
    network-manager     = ["de-0"]
    upstream-dns        = ["gw-0", "gw-1", "q-0", "r-0"]
    gateway             = ["gw-0", "gw-1", "q-0"]
    vrrp                = ["gw-0", "gw-1"]
    disks               = ["gw-0", "gw-1", "q-0", "de-1", "r-0"]
    server              = ["gw-0", "gw-1", "q-0", "de-1", "r-0"]
    client              = ["de-0", "de-1"]
    etcd                = ["gw-0", "gw-1", "q-0"]
    kubernetes-master   = ["gw-0", "gw-1"]
    kubernetes-worker   = ["gw-0", "gw-1", "q-0", "de-1"]
    nvidia-container    = ["de-1"]
    desktop-environment = ["de-0", "de-1"]
    sunshine            = ["de-1"]
    remote              = ["r-0"]
  }

  # finalized local vars #

  hosts = {
    for host_key, host in local.base_hosts :
    host_key => merge(host, {
      hostname           = "${host_key}.${local.domains.mdns}"
      tailscale_hostname = "${host_key}.${local.domains.tailscale}"

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
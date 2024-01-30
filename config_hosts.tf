locals {
  base_hosts = {
    gw-0 = {
      users = [
        "admin",
      ]
      netnum = 1
      physical_interfaces = {
        phy0 = {
          mac   = "1c-83-41-30-e2-23"
          mtu   = 9000
          vlans = ["sync", "etcd", "service", "kubernetes", "wan"]
        }
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
      network_boot = {
        interface = "phy0"
        image     = local.pxeboot_image_set.coreos
        boot_args = [
          "numa=off",
          "systemd.unit=multi-user.target",
          "enforcing=0",
        ]
      }
      kubernetes_node_labels = {
        minio = true
        kea   = true
      }
    }

    gw-1 = {
      users = [
        "admin",
      ]
      netnum = 3
      physical_interfaces = {
        phy0 = {
          mac   = "1c-83-41-30-bd-6f"
          mtu   = 9000
          vlans = ["sync", "etcd", "service", "kubernetes", "wan"]
        }
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
        ]
      }
      kubernetes_node_labels = {
        minio = true
        kea   = true
      }
    }

    q-0 = {
      users = [
        "admin",
      ]
      netnum = 5
      physical_interfaces = {
        phy0 = {
          mac   = "1c-83-41-30-e2-54"
          mtu   = 9000
          vlans = ["sync", "etcd", "service", "kubernetes", "wan"]
        }
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
      network_boot = {
        interface = "phy0"
        image     = local.pxeboot_image_set.coreos
        boot_args = [
          "numa=off",
          "systemd.unit=multi-user.target",
          "enforcing=0",
        ]
      }
      kubernetes_node_labels = {
        minio = true
        kea   = true
      }
    }

    de-1 = {
      users = [
        "client",
      ]
      netnum = 6
      physical_interfaces = {
        phy0 = {
          mac   = "74-56-3c-c3-10-68"
          mtu   = 9000
          vlans = ["service", "kubernetes", "wan"]
        }
        # mobile
        phy1 = {
          mac = "32-57-14-7a-aa-10"
        }
      }
      wlan_interfaces = {
        wlan0 = {
          mac = "10-6f-d9-cf-d5-71"
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
        # shares resource over double NAT LAN
        wan = {
          source_interface_name = "phy0-wan"
          mac                   = ""
          metric                = 4096
          enable_dhcp           = true
          enable_dns            = false
        }
        # backup WAN on mobile data
        mobile = {
          source_interface_name = "phy1"
          enable_dhcp           = true
          metric                = 512
        }
      }
      disks = {
        pv = {
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
        ]
      }
      kubernetes_node_labels = {
        hostapd = true
        nvidia  = true
      }
    }

    # chromebook
    de-0 = {
      users = [
        "client",
      ]
      # same as disk but a hack to use an existing lvm on chromeos
      # ignition doesn't support provisioning lvm device so so systemd mount only
      mounts = [
        {
          device     = "/dev/H3F03NEV207BX1ZE/unencrypted"
          mount_path = local.mounts.home_path
          format     = "ext4"
        },
      ]
    }

    # remote laptop
    r-0 = {
      users = [
        "client",
      ]
      # same as disk but a hack to use an existing lvm on chromeos
      # ignition doesn't support provisioning lvm device so so systemd mount only
      mounts = [
        {
          device     = "/dev/disk/by-label/home"
          mount_path = local.mounts.home_path
          format     = "xfs"
        },
      ]
    }
  }

  base_members = {
    base              = ["gw-0", "gw-1", "q-0", "de-0", "de-1", "r-0"]
    systemd-networkd  = ["gw-0", "gw-1", "q-0", "de-1"]
    network-manager   = ["de-0", "r-0"]
    gateway           = ["gw-0", "gw-1", "q-0"]
    vrrp              = ["gw-0", "gw-1"]
    disks             = ["gw-0", "gw-1", "q-0", "de-1"]
    mounts            = ["de-0", "r-0"]
    ssh-server        = ["gw-0", "gw-1", "q-0", "de-1", "r-0"]
    ssh-client        = ["de-0", "de-1"]
    etcd              = ["gw-0", "gw-1", "q-0"]
    kubernetes-master = ["gw-0", "gw-1"]
    kubernetes-worker = ["gw-0", "gw-1", "q-0", "de-1"]
    nvidia-container  = ["de-1"]
    desktop           = ["de-0", "de-1", "r-0"]
    sunshine          = ["de-1"]
    remote            = ["r-0"]
    chromebook-hacks  = ["de-0"]
  }

  # finalized local vars #

  base_hosts_1 = {
    for host_key, host in local.base_hosts :
    host_key => merge(host, {
      hostname           = "${host_key}.${local.domains.internal_mdns}"
      tailscale_hostname = "${host_key}.${local.domains.tailscale}"

      tap_interfaces = {
        for network_name, tap_interface in lookup(host, "tap_interfaces", {}) :
        network_name => merge(local.networks[network_name], tap_interface, {
          interface_name = network_name
        })
      }

      virtual_interfaces = {
        for network_name, virtual_interface in lookup(host, "virtual_interfaces", {}) :
        network_name => merge(local.networks[network_name], virtual_interface, {
          interface_name = network_name
        })
      }

      physical_interfaces = {
        for hardware_interface_name, hardware_interface in lookup(host, "physical_interfaces", {}) :
        hardware_interface_name => merge(hardware_interface, {
          vlans = {
            for i, network_name in lookup(hardware_interface, "vlans", []) :
            network_name => merge(local.networks[network_name], {
              interface_name = "${hardware_interface_name}-${network_name}"
            })
          }
        })
      }
    })
  }

  hosts = {
    for host_key, host in local.base_hosts_1 :
    host_key => merge(host, {
      networks = {
        for network_name, interface in merge(
          host.tap_interfaces,
          host.virtual_interfaces,
        ) :
        network_name => merge(local.networks[network_name], interface)
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
locals {
  base_hosts = {
    # desktop
    de-1 = {
      netnum = 6
      users = [
        "client",
      ]
      hardware_interfaces = {
        phy0 = {
          mac   = "74-56-3c-c3-10-68"
          mtu   = 9000
          vlans = ["sync", "etcd", "service", "kubernetes", "wan"]
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
          enable_netnum         = true
          enable_dhcp           = true
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
      kubernetes_worker_labels = {
        hostapd = true
        nvidia  = true
        minio   = true
      }
      kubernetes_worker_taints = [
        # {
        #   key    = "node-role.kubernetes.io/de"
        #   effect = "NoSchedule"
        # },
        # {
        #   key    = "node-role.kubernetes.io/de"
        #   effect = "NoExecute"
        # },
      ]
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
          device     = "/dev/disk/by-label/home"
          mount_path = local.mounts.home_path
          format     = "xfs"
        },
      ]
    }

    # backup laptop
    de-2 = {
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
    base              = ["de-0", "de-2", "de-1"]
    systemd-networkd  = ["de-1"]
    network-manager   = ["de-0", "de-2"]
    gateway           = ["de-1"]
    vrrp              = ["de-1"]
    disks             = ["de-1"]
    mounts            = ["de-0", "de-2"]
    ssh-server        = ["de-2", "de-1"]
    ssh-client        = ["de-0", "de-2", "de-1"]
    etcd              = ["de-1"]
    kubelet-base      = ["de-0", "de-2", "de-1"]
    kubernetes-master = ["de-1"]
    kubernetes-worker = ["de-1"]
    nvidia-container  = ["de-1"]
    desktop           = ["de-0", "de-2", "de-1"]
    sunshine          = ["de-1"]
    remote            = ["de-0", "de-2", "de-1"]
    chromebook-hacks  = ["de-0"]
  }

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

      hardware_interfaces = {
        for hardware_interface_name, hardware_interface in lookup(host, "hardware_interfaces", {}) :
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

  # use this instead of base_members #
  members = {
    for key, members in local.base_members :
    key => {
      for host_key in members :
      host_key => local.hosts[host_key]
    }
  }
}

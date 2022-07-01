locals {
  base_hosts = {
    aio-0 = {
      users = [
        "admin"
      ]
      vrrp_netnum = 2
      netnum      = 1
      hardware_interfaces = {
        phy0 = {
          mac   = "1c-83-41-30-e4-b5"
          mtu   = 9000
          vlans = ["sync", "wan"]
        }
        wlan0 = {
          mac          = "90-cc-df-ae-c0-f9"
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
          enable_vrrp_netnum    = true
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
          device = "/dev/disk/by-id/nvme-VICKTER_NVME_SSD_WLN020A01087"
          partitions = [
            {
              mount_path = "/var/pv"
              wipe       = false
            },
          ]
        }
      }
      minio_volume_paths = [
        "/var/pv/minio"
      ]
      container_storage_path = "/var/pv/containers"
    }

    aio-1 = {
      users = [
        "admin"
      ]
      vrrp_netnum = 2
      netnum      = 3
      hardware_interfaces = {
        phy0 = {
          mac   = "1c-83-41-30-e2-54"
          mtu   = 9000
          vlans = ["sync", "wan"]
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
          enable_vrrp_netnum    = true
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
              mount_path = "/var/pv"
              wipe       = false
            },
          ]
        }
      }
      minio_volume_paths = [
        "/var/pv/minio"
      ]
      container_storage_path = "/var/pv/containers"
    }

    client-0 = {
      users = [
        "client"
      ]
      netnum      = 4
      hardware_interfaces = {
        phy0 = {
          mac   = "84-a9-38-0f-aa-76"
          mtu   = 9000
          vlans = ["wan"]
        }
      }
      bridge_interfaces = {}
      tap_interfaces = {
        lan = {
          source_interface_name = "phy0"
          enable_mdns           = true
          enable_netnum         = true
          mtu                   = 9000
        }
        wan = {
          source_interface_name = "phy0-wan"
          enable_dhcp           = false
          mac                   = "52-54-00-63-6e-b3"
        }
      }
      disks = {
        pv = {
          device = "/dev/disk/by-id/nvme-SKHynix_HFS512GDE9X084N_CYA8N037413008I5H"
          partitions = [
            {
              mount_path = "/var/home"
              wipe       = false
            },
          ]
        }
      }
      minio_volume_paths = [
        "/var/home/minio"
      ]
      container_storage_path = "/var/home/containers"
      kubernetes_worker_taints = {
        "nvidia.com/gpu" = "true:NoSchedule"
      }
    }

    remote-0 = {
      users = [
        "client"
      ]
      disks = {
        pv = {
          device = "/dev/disk/by-id/nvme-SKHynix_HFS512GDE9X084N_CYA8N037413008I5H"
          partitions = [
            {
              mount_path = "/var/home"
              wipe       = false
            },
          ]
        }
      }
      container_storage_path = "/var/home/containers"
    }
  }

  hosts = {
    for host_key, host in local.base_hosts :
    host_key => merge(host, {
      hostname = "${host_key}.${local.domains.internal_mdns}"
    })
  }
}
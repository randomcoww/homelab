locals {
  host_spec = {
    server-laptop = {
      hardware_interfaces = {
        phy0 = {
          mac   = "8c-8c-aa-e3-58-62"
          mtu   = 9000
          vlans = ["sync", "wan"]
        }
        wlan0 = {
          mac = "b4-0e-de-fb-28-95"
          mtu = 9000
        }
      }
      tap_interfaces = {
        lan = {
          source_interface_name = "br-wlan"
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
          device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_1TB_S5H9NS0N986704R"
          partitions = [
            {
              mount_path = "/var/pv"
              wipe       = false
            },
          ]
        }
      }
      volume_paths = [
        "/var/pv/minio"
      ]
      container_storage_path = "/var/pv/containers"
    }

    server-supermicro = {
      hardware_interfaces = {
        phy0 = {
          mac = "3c-fd-fe-b2-47-68"
          mtu = 9000
        }
        phy1 = {
          mac   = "3c-fd-fe-b2-47-69"
          mtu   = 9000
          vlans = ["sync"]
        }
        phy2 = {
          mac   = "3c-fd-fe-b2-47-6a"
          mtu   = 9000
          vlans = ["wan"]
        }
        phy3 = {
          mac   = "3c-fd-fe-b2-47-6b"
          mtu   = 9000
          vlans = ["wlan"]
        }
      }
      tap_interfaces = {
        lan = {
          source_interface_name = "phy0"
          enable_mdns           = true
          enable_netnum         = true
          enable_vrrp_netnum    = true
          enable_dhcp_server    = true
          mtu                   = 9000
        }
        sync = {
          source_interface_name = "phy1-sync"
          enable_netnum         = true
          enable_vrrp_netnum    = true
          mtu                   = 9000
        }
        wan = {
          source_interface_name = "phy2-wan"
          enable_dhcp           = true
          mac                   = "52-54-00-63-6e-b3"
        }
      }
      disks                  = {}
      volume_paths           = []
      container_storage_path = "/var/lib/containers"
    }

    client-ws = {
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
      volume_paths = [
        "/var/home/minio"
      ]
      container_storage_path = "/var/home/containers"
    }
  }
}
locals {
  base_hosts = {
    aio-0 = {
      vrrp_netnum = 2
      netnum      = 1
      hardware_interfaces = {
        phy0 = {
          mac   = "8c-8c-aa-e3-58-62"
          mtu   = 9000
          vlans = ["sync", "wan"]
        }
        wlan0 = {
          mac          = "b4-0e-de-fb-28-95"
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
          device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_1TB_S5H9NS0N986704R"
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
      netnum = 3
      hardware_interfaces = {
        phy0 = {
          mac   = "84-a9-38-0f-aa-76"
          mtu   = 9000
          vlans = ["sync", "wan"]
        }
        wlan0 = {
          mac = "b4-b5-b6-74-79-15"
          mtu = 9000
        }
      }
      bridge_interfaces = {
        br-lan = {
          interfaces = ["phy0"]
          mtu        = 9000
        }
      }
      tap_interfaces = {
        lan = {
          source_interface_name = "br-lan"
          enable_mdns           = true
          enable_dhcp           = true
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
    }

    store-0 = {
      netnum = 4
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
          mac = "3c-fd-fe-b2-47-6b"
          mtu = 9000
        }
      }
    }
  }

  hosts = {
    for host_key, host in local.base_hosts :
    host_key => merge(host, {
      hostname = "${host_key}.${local.domains.internal_mdns}"
    })
  }
}
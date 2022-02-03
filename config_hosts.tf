locals {
  host_spec = {
    aio-0 = {
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
      minio_volume_paths = [
        "/var/pv/minio"
      ]
      container_storage_path = "/var/pv/containers"
    }

    router-0 = {
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

    client-0 = {
      hardware_interfaces = {
        lan = {
          mac = "84-a9-38-0f-aa-76"
          mtu = 9000
        }
        wlan0 = {
          mac = "42-5b-7d-9f-1a-90"
          mtu = 9000
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
  }

  # host classes #
  aio_hostclass_config = {
    vrrp_netnum = 2
    dhcp_server_subnet = {
      newbit = 1
      netnum = 1
    }
    hosts = {
      aio-0 = merge(local.host_spec.aio-0, {
        hostname    = "aio-0.${local.domains.internal_mdns}"
        netnum      = 1
        kea_ha_role = "primary"
      })
    }
  }

  client_hostclass_config = {
    hosts = {
      client-0 = merge(local.host_spec.client-0, {
        hostname = "client-0.${local.domains.internal_mdns}"
      })
    }
  }

  router_hostclass_config = {
    vrrp_netnum = 2
    dhcp_server_subnet = {
      newbit = 1
      netnum = 1
    }
    hosts = {
      router-0 = merge(local.host_spec.router-0, {
        hostname    = "router-0.${local.domains.internal_mdns}"
        netnum      = 3
        kea_ha_role = "secondary"
      })
    }
  }
}
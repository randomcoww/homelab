locals {
  host_spec = {
    server-laptop = {
      netnum = 1
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

    client-laptop = {
      netnum = 3
      hardware_interfaces = {
        phy0 = {
          mac   = "84-a9-38-0f-aa-76"
          mtu   = 9000
          vlans = ["sync", "wan"]
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

    supermicro-server = {
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
      disks                  = {}
      volume_paths           = []
      container_storage_path = "/var/lib/containers"
    }
  }
}
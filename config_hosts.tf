locals {
  hosts = {
    for key, config in {
      k-0 = {
        netnum = 1
        physical_interfaces = [
          {
            match_mac = "b0-41-6f-16-a2-dc"
            # match_mac = "b0-41-6f-16-a2-dd"
            interface = "phy0"
            altnames  = [local.networks.lan.interface]
          },
        ]
        vlan_interfaces = [
          merge(local.networks.node, {
            source = "phy0"
          }),
          merge(local.networks.service, {
            source = "phy0"
          }),
          merge(local.networks.etcd, {
            source = "phy0"
          }),
          merge(local.networks.wan, {
            source = "phy0"
            mac    = "52-54-00-63-6e-b3"
          }),
        ]
        network_overrides = [
          merge(local.networks.lan, {
            source = "phy0"
          }),
          merge(local.networks.node, {
            source = local.networks.node.interface
          }),
          merge(local.networks.service, {
            source = local.networks.service.interface
          }),
          merge(local.networks.etcd, {
            source = local.networks.etcd.interface
          }),
          merge(local.networks.wan, {
            source = local.networks.wan.interface
          }),
        ]
        disks = [
          {
            label  = "pv"
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
          },
        ]
        boot_args = [
          "ttm.pages_limit=${32 * 512 * 512}",   # 32G
          "ttm.page_pool_size=${1 * 512 * 512}", # 1G preallocated
          "pcie_aspm=off",                       # TODO: workaround for r8169 transmit queue timed out issue
        ]
      }

      k-1 = {
        netnum = 3
        physical_interfaces = [
          {
            match_mac = "b0-41-6f-16-f9-88"
            # match_mac = "b0-41-6f-16-f9-89"
            interface = "phy0"
            altnames  = [local.networks.lan.interface]
          },
        ]
        vlan_interfaces = [
          merge(local.networks.node, {
            source = "phy0"
          }),
          merge(local.networks.service, {
            source = "phy0"
          }),
          merge(local.networks.etcd, {
            source = "phy0"
          }),
          merge(local.networks.wan, {
            source = "phy0"
            mac    = "52-54-00-63-6e-b3"
          }),
        ]
        network_overrides = [
          merge(local.networks.lan, {
            source = "phy0"
          }),
          merge(local.networks.node, {
            source = local.networks.node.interface
          }),
          merge(local.networks.service, {
            source = local.networks.service.interface
          }),
          merge(local.networks.etcd, {
            source = local.networks.etcd.interface
          }),
          merge(local.networks.wan, {
            source = local.networks.wan.interface
          }),
        ]
        disks = [
          {
            label  = "pv"
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
          },
        ]
        boot_args = [
          "ttm.pages_limit=${32 * 512 * 512}",   # 32G
          "ttm.page_pool_size=${1 * 512 * 512}", # 1G preallocated
          "pcie_aspm=off",                       # TODO: workaround for r8169 transmit queue timed out issue
        ]
      }

      k-2 = {
        netnum = 5
        physical_interfaces = [
          {
            match_mac = "b0-41-6f-16-9e-76"
            # match_mac = "b0-41-6f-16-9e-77"
            interface = "phy0"
            altnames  = [local.networks.lan.interface]
          }
        ]
        vlan_interfaces = [
          merge(local.networks.node, {
            source = "phy0"
          }),
          merge(local.networks.service, {
            source = "phy0"
          }),
          merge(local.networks.etcd, {
            source = "phy0"
          }),
        ]
        network_overrides = [
          merge(local.networks.lan, {
            source = "phy0"
          }),
          merge(local.networks.node, {
            source = local.networks.node.interface
          }),
          merge(local.networks.service, {
            source = local.networks.service.interface
          }),
          merge(local.networks.etcd, {
            source = local.networks.etcd.interface
          }),
        ]
        disks = [
          {
            label  = "pv"
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
          },
        ]
        boot_args = [
          "ttm.pages_limit=${32 * 512 * 512}",   # 32G
          "ttm.page_pool_size=${1 * 512 * 512}", # 1G preallocated
          "pcie_aspm=off",                       # TODO: workaround for r8169 transmit queue timed out issue
        ]
      }

      k-3 = {
        netnum = 6
        physical_interfaces = [
          {
            match_mac = "9c-bf-0d-01-0e-7b"
            interface = "phy0"
          },
          {
            match_mac = "dc-56-7b-03-4c-e5" # MT7925
            interface = "wlan0"
          },
        ]
        vlan_interfaces = [
          merge(local.networks.node, {
            source = "phy0"
          }),
          merge(local.networks.service, {
            source = "phy0"
          }),
          merge(local.networks.etcd, {
            source = "phy0"
          }),
        ]
        bridge_interfaces = [
          merge(local.networks.lan, {
            sources = ["phy0"]
          }),
        ]
        network_overrides = [
          merge(local.networks.lan, {
            source = local.networks.lan.interface
          }),
          merge(local.networks.node, {
            source = local.networks.node.interface
          }),
          merge(local.networks.service, {
            source = local.networks.service.interface
          }),
          merge(local.networks.etcd, {
            source = local.networks.etcd.interface
          }),
          merge(local.networks.wan, {
            source = local.networks.wan.interface
          }),
        ]
        disks = [
          {
            label  = "pv"
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
          },
        ]
        boot_args = [
          "ttm.pages_limit=${128 * 512 * 512}",   # 128G https://community.frame.work/t/igpu-vram-how-much-can-be-assigned/73081
          "ttm.page_pool_size=${96 * 512 * 512}", # 96G preallocated
          "pcie_aspm=off",                        # TODO: workaround for r8169 transmit queue timed out issue
          "mt7925e.disable_aspm=1",               # TODO: workaround for mt7925e stability
          "mt7925_common.disable_clc=1",          # TODO: workaround for mt7925e stability
          "swiotlb=65536",                        # TODO: workaround for mt7925e stability
        ]
      }
    } :
    key => merge(config, {
      key = key
      networks = {
        for _, network in lookup(config, "network_overrides", []) :
        network.key => network
      }
    })
  }

  members = {
    for type, members in {
      base              = ["k-0", "k-1", "k-2", "k-3"]
      systemd-networkd  = ["k-0", "k-1", "k-2", "k-3"]
      server            = ["k-0", "k-1", "k-2", "k-3"]
      disks             = ["k-0", "k-1", "k-2", "k-3"]
      upstream-dns      = ["k-0", "k-1", "k-2", "k-3"]
      gateway           = ["k-0", "k-1"]
      kubernetes-master = ["k-2", "k-3"]
      etcd              = ["k-0", "k-1", "k-2"]
      kubernetes-worker = ["k-0", "k-1", "k-2", "k-3"]
    } :
    type => {
      for _, key in members :
      key => local.hosts[key]
    }
  }
}
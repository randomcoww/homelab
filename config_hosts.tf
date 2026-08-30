locals {
  hosts = {
    for key, config in {
      k-0 = {
        netnum = 1
        wired_interfaces = [
          {
            match_mac = "b0-41-6f-16-a2-dc"
            # match_mac = "b0-41-6f-16-a2-dd"
            interface = local.networks.lan.interface
          },
        ]
        vlan_interfaces = [
          {
            source    = local.networks.lan.interface
            interface = local.networks.node.interface
            vlan_id   = local.networks.node.vlan_id
          },
          {
            source    = local.networks.lan.interface
            interface = local.networks.service.interface
            vlan_id   = local.networks.service.vlan_id
          },
          {
            source    = local.networks.lan.interface
            interface = local.networks.etcd.interface
            vlan_id   = local.networks.etcd.vlan_id
          },
          {
            source    = local.networks.lan.interface
            interface = "${local.networks.wan.interface}-base"
            vlan_id   = local.networks.wan.vlan_id
          },
        ]
        macvlan_interfaces = [
          {
            source    = "${local.networks.wan.interface}-base"
            interface = local.networks.wan.interface
            mac       = local.networks.wan.mac
          },
        ]
        interface_overrides = [
          merge(local.networks.lan, {
            interface = local.networks.lan.interface
          }),
          merge(local.networks.node, {
            interface = local.networks.node.interface
          }),
          merge(local.networks.service, {
            interface = local.networks.service.interface
          }),
          merge(local.networks.etcd, {
            interface = local.networks.etcd.interface
          }),
          merge(local.networks.wan, {
            interface = local.networks.wan.interface
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
        wired_interfaces = [
          {
            match_mac = "b0-41-6f-16-f9-88"
            # match_mac = "b0-41-6f-16-f9-89"
            interface = local.networks.lan.interface
          },
        ]
        vlan_interfaces = [
          {
            source    = local.networks.lan.interface
            interface = local.networks.node.interface
            vlan_id   = local.networks.node.vlan_id
          },
          {
            source    = local.networks.lan.interface
            interface = local.networks.service.interface
            vlan_id   = local.networks.service.vlan_id
          },
          {
            source    = local.networks.lan.interface
            interface = local.networks.etcd.interface
            vlan_id   = local.networks.etcd.vlan_id
          },
          {
            source    = local.networks.lan.interface
            interface = "${local.networks.wan.interface}-base"
            vlan_id   = local.networks.wan.vlan_id
          },
        ]
        macvlan_interfaces = [
          {
            source    = "${local.networks.wan.interface}-base"
            interface = local.networks.wan.interface
            mac       = local.networks.wan.mac
          },
        ]
        interface_overrides = [
          merge(local.networks.lan, {
            interface = local.networks.lan.interface
          }),
          merge(local.networks.node, {
            interface = local.networks.node.interface
          }),
          merge(local.networks.service, {
            interface = local.networks.service.interface
          }),
          merge(local.networks.etcd, {
            interface = local.networks.etcd.interface
          }),
          merge(local.networks.wan, {
            interface = local.networks.wan.interface
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
        wired_interfaces = [
          {
            match_mac = "b0-41-6f-16-9e-76"
            # match_mac = "b0-41-6f-16-9e-77"
            interface = local.networks.lan.interface
          },
        ]
        vlan_interfaces = [
          {
            source    = local.networks.lan.interface
            interface = local.networks.node.interface
            vlan_id   = local.networks.node.vlan_id
          },
          {
            source    = local.networks.lan.interface
            interface = local.networks.service.interface
            vlan_id   = local.networks.service.vlan_id
          },
          {
            source    = local.networks.lan.interface
            interface = local.networks.etcd.interface
            vlan_id   = local.networks.etcd.vlan_id
          },
        ]
        interface_overrides = [
          merge(local.networks.lan, {
            interface = local.networks.lan.interface
          }),
          merge(local.networks.node, {
            interface = local.networks.node.interface
          }),
          merge(local.networks.service, {
            interface = local.networks.service.interface
          }),
          merge(local.networks.etcd, {
            interface = local.networks.etcd.interface
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
        wired_interfaces = [
          {
            match_mac = "9c-bf-0d-01-0e-7b"
            interface = "phy0"
          },
        ]
        wireless_interfaces = [
          {
            match_mac = "dc-56-7b-03-4c-e5" # MT7925
            interface = "wlan0"
          },
        ]
        vlan_interfaces = [
          {
            source    = "phy0"
            interface = local.networks.node.interface
            vlan_id   = local.networks.node.vlan_id
          },
          {
            source    = "phy0"
            interface = local.networks.service.interface
            vlan_id   = local.networks.service.vlan_id
          },
          {
            source    = "phy0"
            interface = local.networks.etcd.interface
            vlan_id   = local.networks.etcd.vlan_id
          },
        ]
        bridge_interfaces = [
          {
            sources   = ["phy0"]
            interface = local.networks.lan.interface
          },
        ]
        interface_overrides = [
          merge(local.networks.lan, {
            interface = local.networks.lan.interface
          }),
          merge(local.networks.node, {
            interface = local.networks.node.interface
          }),
          merge(local.networks.service, {
            interface = local.networks.service.interface
          }),
          merge(local.networks.etcd, {
            interface = local.networks.etcd.interface
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
        for _, config in lookup(config, "interface_overrides", []) :
        config.key => config
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
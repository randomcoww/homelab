locals {
  user               = "core"
  mtu                = 9000
  kubernetes_version = "v1.17.2"

  # kubelet image is used for static pods and does not need to match the kubernetes version
  # hyperkube is used for the worker kubelet and should match the version
  container_images = {
    kubelet                 = "docker.io/randomcoww/kubernetes:kubelet-v1.18.2"
    kube_apiserver          = "docker.io/randomcoww/kubernetes:kube-master-${local.kubernetes_version}"
    kube_controller_manager = "docker.io/randomcoww/kubernetes:kube-master-${local.kubernetes_version}"
    kube_scheduler          = "docker.io/randomcoww/kubernetes:kube-master-${local.kubernetes_version}"
    hyperkube               = "docker.io/randomcoww/kubernetes:kubelet-${local.kubernetes_version}"
    kube_proxy              = "docker.io/randomcoww/kubernetes:kube-proxy-${local.kubernetes_version}"
    etcd_wrapper            = "docker.io/randomcoww/etcd-wrapper:v0.2.0"
    etcd                    = "docker.io/randomcoww/etcd:v3.4.7"
    flannel                 = "docker.io/randomcoww/flannel:latest"
    keepalived              = "docker.io/randomcoww/keepalived:latest"
    cni_plugins             = "docker.io/randomcoww/cni-plugins:v0.8.5"
    coredns                 = "docker.io/coredns/coredns:1.6.9"
    external_dns            = "docker.io/randomcoww/external-dns:v0.7.1"
    kapprover               = "docker.io/randomcoww/kapprover:v0.0.4"
    nftables                = "docker.io/randomcoww/nftables:latest"
    kea                     = "docker.io/randomcoww/kea:1.6.2"
    conntrackd              = "docker.io/randomcoww/conntrackd:latest"
    promtail                = "docker.io/randomcoww/promtail:v1.4.1"
    matchbox                = "quay.io/poseidon/matchbox:latest"
    loki                    = "docker.io/grafana/loki:latest"
  }

  ## images served from matchbox
  kernel_image = "fedora-coreos-live-kernel"
  initrd_images = [
    "fedora-coreos-live-initramfs.img"
  ]
  kernel_params = [
    "console=hvc0",
    "rd.neednet=1",
    "ignition.firstboot",
    "ignition.platform.id=metal",
    "net.ifnames=0",
    "biosdevname=0",
    "systemd.unified_cgroup_hierarchy=0",
  ]

  services = {
    # local dev
    local_renderer = {
      ports = {
        http = 8080
        rpc  = 8081
      }
    }
    # hypervisor internal
    renderer = {
      vip = "192.168.224.1"
      ports = {
        http = 80
        rpc  = 58081
      }
    }

    # outside of kubernetes network
    kea = {
      ports = {
        peer = 58082
      }
    }
    recursive_dns = {
      vip = "192.168.126.241"
      ports = {
        prometheus = 59153
      }
    }
    internal_dns = {
      vip = "192.168.126.127"
      ports = {
        prometheus = 59153
      }
    }
    loki = {
      vip = "192.168.126.126"
      ports = {
        http_listen = 3100
      }
    }

    # kubernetes network
    kubernetes_apiserver = {
      vip = "192.168.126.245"
      ports = {
        secure = 56443
      }
    }
    kubernetes_service = {
      vip = "10.96.0.1"
    }
    kubernetes_dns = {
      vip = "10.96.0.10"
    }
    etcd = {
      ports = {
        peer   = 52380
        client = 52379
      }
    }
  }

  domains = {
    internal           = "fuzzybunny.internal"
    kubernetes_cluster = "cluster.local"
  }

  networks = {
    # vlans
    store = {
      id        = 1
      network   = "192.168.126.0"
      cidr      = 23
      router    = "192.168.126.240"
      dhcp_pool = "192.168.127.64/26"
      br_if     = "en-store"
    }
    lan = {
      id        = 90
      network   = "192.168.62.0"
      cidr      = 23
      router    = "192.168.62.240"
      dhcp_pool = "192.168.63.64/26"
      br_if     = "en-lan"
    }
    sync = {
      id      = 60
      network = "192.168.190.0"
      cidr    = 29
      br_if   = "en-sync"
    }
    wan = {
      id    = 30
      br_if = "en-wan"
    }
    # internal network on each hypervisor
    int = {
      network   = "192.168.224.0"
      cidr      = 23
      dhcp_pool = "192.168.225.64/26"
      br_if     = "en-int"
    }
    # kubernetes
    kubernetes = {
      network = "10.244.0.0"
      cidr    = 16
    }
    kubernetes_service = {
      network = "10.96.0.0"
      cidr    = 12
    }
    metallb = {
      network = "192.168.126.64"
      cidr    = 26
    }
  }

  hosts = {
    # gateway
    gateway-0 = {
      components = [
        "gateway"
      ]
      memory = 2
      vcpu   = 1
      network = [
        {
          network = "store"
          ip      = "192.168.127.217"
          if      = "eth0"
        },
        {
          network = "lan"
          ip      = "192.168.63.217"
          if      = "eth1"
        },
        {
          network = "sync"
          ip      = "192.168.190.1"
          if      = "eth2"
        },
        {
          alias   = "host_wan"
          network = "wan"
          if      = "eth3"
          mac     = "52-54-00-63-6e-b2"
        },
        {
          network     = "wan"
          if          = "eth4"
          mac         = "52-54-00-63-6e-b3"
          route_table = 250
        },
        {
          network   = "int"
          if        = "eth5"
          mac       = "52-54-00-1a-61-2a"
          bootorder = 1
        }
      ]
      kea_ha_role = "primary"
    }
    gateway-1 = {
      components = [
        "gateway"
      ]
      memory = 2
      vcpu   = 1
      network = [
        {
          network = "store"
          ip      = "192.168.127.218"
          if      = "eth0"
        },
        {
          network = "lan"
          ip      = "192.168.63.218"
          if      = "eth1"
        },
        {
          network = "sync"
          ip      = "192.168.190.2"
          if      = "eth2"
        },
        {
          alias   = "host_wan"
          network = "wan"
          if      = "eth3"
          mac     = "52-54-00-63-6e-b1"
        },
        {
          network     = "wan"
          if          = "eth4"
          mac         = "52-54-00-63-6e-b3"
          route_table = 250
        },
        {
          network   = "int"
          if        = "eth5"
          mac       = "52-54-00-1a-61-2b"
          bootorder = 1
        }
      ]
      kea_ha_role = "standby"
    }

    # controllers
    controller-0 = {
      memory = 4
      vcpu   = 2
      components = [
        "controller"
      ]
      network = [
        {
          network = "store"
          ip      = "192.168.127.219"
          if      = "eth0"
        },
        {
          network   = "int"
          if        = "eth1"
          mac       = "52-54-00-1a-61-0a"
          bootorder = 1
        }
      ]
    }
    controller-1 = {
      memory = 4
      vcpu   = 2
      components = [
        "controller"
      ]
      network = [
        {
          network = "store"
          ip      = "192.168.127.220"
          if      = "eth0"
        },
        {
          network   = "int"
          if        = "eth1"
          mac       = "52-54-00-1a-61-0b"
          bootorder = 1
        }
      ]
    }
    controller-2 = {
      memory = 4
      vcpu   = 2
      components = [
        "controller"
      ]
      network = [
        {
          network = "store"
          ip      = "192.168.127.221"
          if      = "eth0"
        },
        {
          network   = "int"
          if        = "eth1"
          mac       = "52-54-00-1a-61-0c"
          bootorder = 1
        }
      ]
    }

    # workers
    worker-0 = {
      components = [
        "worker"
      ]
      memory = 48
      vcpu   = 4
      network = [
        {
          network = "store"
          ip      = "192.168.127.222"
          if      = "eth0"
        },
        {
          network   = "int"
          if        = "eth1"
          mac       = "52-54-00-1a-61-1a"
          bootorder = 1
        }
      ]
      hostdev = [
        {
          domain   = "0x0000"
          bus      = "0x05"
          slot     = "0x00"
          function = "0x0"
          rom      = "/etc/libvirt/boot/SAS9300_8i_IT.bin"
        }
      ]
      # Defaults:
      # format = "xfs"
      # wipe_filesystem = false
      disk = [
        {
          label      = "2YK7XTRD"
          device     = "/dev/disk/by-id/ata-WDC_WD100EFAX-68LHPN0_2YK7XTRD"
          mount_path = "/var/s3/0"
        },
        {
          label      = "2YK87AVD"
          device     = "/dev/disk/by-id/ata-WDC_WD100EFAX-68LHPN0_2YK87AVD"
          mount_path = "/var/s3/1"
        },
        {
          label      = "2YK89PND"
          device     = "/dev/disk/by-id/ata-WDC_WD100EFAX-68LHPN0_2YK89PND"
          mount_path = "/var/s3/2"
        },
        {
          label      = "2YKG1X2D"
          device     = "/dev/disk/by-id/ata-WDC_WD100EFAX-68LHPN0_2YKG1X2D"
          mount_path = "/var/s3/3"
        },
        {
          label      = "2YKGML5D"
          device     = "/dev/disk/by-id/ata-WDC_WD100EFAX-68LHPN0_2YKGML5D"
          mount_path = "/var/s3/4"
        },
        {
          label      = "2YKGML7D"
          device     = "/dev/disk/by-id/ata-WDC_WD100EFAX-68LHPN0_2YKGML7D"
          mount_path = "/var/s3/5"
        },
        {
          label      = "2YKGNL4D"
          device     = "/dev/disk/by-id/ata-WDC_WD100EFAX-68LHPN0_2YKGNL4D"
          mount_path = "/var/s3/6"
        },
        {
          label      = "JEK830AZ"
          device     = "/dev/disk/by-id/ata-WDC_WD100EFAX-68LHPN0_JEK830AZ"
          mount_path = "/var/s3/7"
        },
        {
          label      = "JEK830RZ"
          device     = "/dev/disk/by-id/ata-WDC_WD100EFAX-68LHPN0_JEK830RZ"
          mount_path = "/var/s3/8"
        },
        {
          label      = "JEK8V1YZ"
          device     = "/dev/disk/by-id/ata-WDC_WD100EFAX-68LHPN0_JEK8V1YZ"
          mount_path = "/var/s3/9"
        },
        {
          label      = "JEK8YTSZ"
          device     = "/dev/disk/by-id/ata-WDC_WD100EFAX-68LHPN0_JEK8YTSZ"
          mount_path = "/var/s3/10"
        },
        {
          label      = "JEKAZ92N"
          device     = "/dev/disk/by-id/ata-WDC_WD100EFAX-68LHPN0_JEKAZ92N"
          mount_path = "/var/s3/11"
        },
        {
          label      = "S4PGNF0M414895K"
          source     = "/dev/disk/by-id/ata-Samsung_SSD_860_QVO_1TB_S4PGNF0M414895K"
          target     = "vda"
          device     = "/dev/vda"
          format     = "ext4"
          mount_path = "/var/pv"
        },
      ]
    }
    worker-1 = {
      components = [
        "worker"
      ]
      memory = 48
      vcpu   = 4
      network = [
        {
          network = "store"
          ip      = "192.168.127.223"
          if      = "eth0"
        },
        {
          network   = "int"
          if        = "eth1"
          mac       = "52-54-00-1a-61-1b"
          bootorder = 1
        }
      ]
      hostdev = [
        {
          domain   = "0x0000"
          bus      = "0x05"
          slot     = "0x00"
          function = "0x0"
          rom      = "/etc/libvirt/boot/SAS9300_8i_IT.bin"
        }
      ]
      # Defaults:
      # format = "xfs"
      # wipe_filesystem = false
      disk = [
        {
          label      = "S4PGNF0M410395Z"
          source     = "/dev/disk/by-id/ata-Samsung_SSD_860_QVO_1TB_S4PGNF0M410395Z"
          target     = "vda"
          device     = "/dev/vda"
          format     = "ext4"
          mount_path = "/var/pv"
        }
      ]
    }

    # Test instances
    test-0 = {
      memory = 4
      vcpu   = 2
      components = [
        "test"
      ]
      network = [
        {
          network = "store"
          if      = "eth0"
        },
        {
          network   = "int"
          if        = "eth1"
          mac       = "52-54-00-1a-61-3a"
          bootorder = 1
        }
      ]
    }

    # KVM
    kvm-0 = {
      components = [
        "kvm"
      ]
      network = [
        {
          alias = "hw"
          mac   = "00-1b-21-bc-4c-16"
        },
        {
          network = "store"
          ip      = "192.168.127.251"
        }
      ]
      guests = [
        "gateway-0",
        "controller-0",
        "controller-2",
        "worker-0",
      ]
    }
    kvm-1 = {
      components = [
        "kvm"
      ]
      network = [
        {
          alias = "hw"
          mac   = "00-1b-21-bc-67-c6"
        },
        {
          network = "store"
          ip      = "192.168.127.252"
        }
      ]
      guests = [
        "gateway-1",
        "controller-1",
        "controller-2",
        "worker-1",
      ]
    }

    # desktop
    desktop = {
      components = [
        "kvm",
        "desktop",
      ]
      network = [
        {
          alias = "hw"
          mac   = "f8-f2-1e-1e-3c-40"
        },
        {
          network = "store"
          ip      = "192.168.127.253"
        }
      ]
    }
  }
}
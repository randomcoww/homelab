locals {
  # Path for etcd backup to S3
  aws_region              = "us-west-2"
  s3_etcd_backup_bucket   = "randomcoww-etcd-backup"
  kubernetes_cluster_name = "default-cluster-2012-1"
  # kubelet image is used for static pods and does not need to match the kubernetes version
  # hyperkube is used for the worker kubelet and should match the version
  container_images = {
    kubelet                 = "docker.io/randomcoww/kubernetes:kubelet-v1.20.0"
    kube_apiserver          = "docker.io/randomcoww/kubernetes:kube-master-v1.20.0"
    kube_controller_manager = "docker.io/randomcoww/kubernetes:kube-master-v1.20.0"
    kube_scheduler          = "docker.io/randomcoww/kubernetes:kube-master-v1.20.0"
    hyperkube               = "docker.io/randomcoww/kubernetes:kubelet-v1.20.0"
    kube_proxy              = "docker.io/randomcoww/kubernetes:kube-proxy-v1.20.0"
    etcd_wrapper            = "docker.io/randomcoww/etcd-wrapper:v0.2.6"
    etcd                    = "docker.io/randomcoww/etcd:v3.4.13"
    flannel                 = "docker.io/randomcoww/flannel:latest"
    keepalived              = "docker.io/randomcoww/keepalived:latest"
    cni_plugins             = "docker.io/randomcoww/cni-plugins:v0.8.7"
    coredns                 = "docker.io/coredns/coredns:1.8.0"
    external_dns            = "registry.opensource.zalan.do/teapot/external-dns:latest"
    kapprover               = "docker.io/randomcoww/kapprover:v0.0.6"
    kea                     = "docker.io/randomcoww/kea:1.8.1"
    conntrackd              = "docker.io/randomcoww/conntrackd:latest"
    promtail                = "docker.io/randomcoww/promtail:v2.0.0"
    tftpd                   = "docker.io/randomcoww/tftpd-ipxe:latest"
    matchbox                = "quay.io/poseidon/matchbox:latest"
    tw                      = "docker.io/randomcoww/tf-env:latest"
  }

  users = {
    # Servers
    default = {
      name = "fcos"
    }
    # Clients
    client = {
      name = "randomcoww"
      uid  = 10000
      home = "/var/lib/kubelet/pv/randomcoww"
    }
  }

  services = {
    # hypervisor internal
    renderer = {
      vip = "192.168.224.1"
      ports = {
        http = 80
        rpc  = 58081
      }
    }
    libvirtd = {
      ports = {
        tls = 16514
      }
    }

    # gateway
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
    # Resolve ingress and metallb names - should be in a metallb pool
    internal_dns = {
      vip = "192.168.126.127"
      ports = {
        prometheus = 59153
      }
    }
    upstream_dns = {
      vip = "9.9.9.9"
      url = "dns.quad9.net"
    }

    # Log collector - should be in metallb a pool
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

    # Externally forwarded to internal IP - should be in a metallb pool
    external_dnat = {
      vip = "192.168.126.125"
      ports = {
        https = 8080
      }
    }

    # nodePort and clusterIP must be specified for LB services to work with
    # the terraform kubernetes-alpha provider. Probably a bug?
    # TODO: Remove once not needed by provider
    kubernetes_external_dns_tcp = {
      vip = "10.100.0.100"
      ports = {
        node = 31800
      }
    }
    kubernetes_external_dns_udp = {
      vip = "10.100.0.101"
      ports = {
        node = 31801
      }
    }
    kubernetes_loki = {
      vip = "10.100.0.102"
      ports = {
        node = 31802
      }
    }
  }

  domains = {
    internal           = "fuzzybunny.internal"
    internal_mdns      = "local"
    kubernetes_cluster = "cluster.internal"
  }

  components = {
    base = {
      nodes = [
        "gateway-0",
        "gateway-1",
        "ns-0",
        "ns-1",
        "controller-0",
        "controller-1",
        "controller-2",
        "worker-0",
        "worker-2",
        "kvm-0",
        "kvm-2",
        "client-0",
      ]
    }
    # coreos hypervisor
    hypervisor = {
      nodes = [
        "kvm-0",
        "kvm-2",
        "client-0",
      ]
      iso_mount_path = "/run/media/iso"
      kernel_image   = "/assets/images/pxeboot/vmlinuz"
      initrd_images = [
        "/assets/images/pxeboot/initrd.img",
        "/assets/images/pxeboot/rootfs.img",
      ]
      metadata = {
        vlan = "metadata"
        if   = "en-md"
        ip   = local.services.renderer.vip
      }
    }
    # coreos VMs
    vm = {
      nodes = [
        "gateway-0",
        "gateway-1",
        "ns-0",
        "ns-1",
        "controller-0",
        "controller-1",
        "controller-2",
        "worker-0",
        "worker-2",
      ]
      kernel_params = [
        "console=hvc0",
        "rd.neednet=1",
        "ignition.firstboot",
        "ignition.platform.id=metal",
        "systemd.unified_cgroup_hierarchy=0",
        "systemd.unit=multi-user.target",
      ]
      metadata = {
        vlan = "metadata"
        if   = "ens2"
      }
    }
    kubelet = {
      nodes = [
        "gateway-0",
        "gateway-1",
        "ns-0",
        "ns-1",
        "controller-0",
        "controller-1",
        "controller-2",
        "worker-0",
        "worker-2",
      ]
    }
    server = {
      nodes = [
        "gateway-0",
        "gateway-1",
        "ns-0",
        "ns-1",
        "controller-0",
        "controller-1",
        "controller-2",
        "worker-0",
        "worker-2",
        "kvm-0",
        "kvm-2",
        "client-0",
      ]
    }
    # silverblue (gnome) desktop with networkmanager
    client = {
      nodes = [
        "client-0",
      ]
    }
    laptop = {
      nodes = [
      ]
    }
    # server certs for SSH CA
    ssh_server = {
      nodes = [
        "gateway-0",
        "gateway-1",
        "ns-0",
        "ns-1",
        "controller-0",
        "controller-1",
        "controller-2",
        "worker-0",
        "worker-2",
        "kvm-0",
        "kvm-2",
        "client-0",
      ]
    }
    ssh_client = {
      nodes = [
        "client-0",
      ]
    }
    # cert for fuzzybunny.internal
    ingress = {
      nodes = [
        "client-0",
      ]
    }
    # promtail to push logs to loki (non kubernetes containerd hosts)
    static_pod_logging = {
      nodes = [
      ]
    }
    # IPMI fan control for Supermicro motherboards
    ipmi_fan_control = {
      nodes = [
        "kvm-2",
      ]
    }

    # host specific
    gateway = {
      memory = 4
      vcpu   = 1
      nodes = [
        "gateway-0",
        "gateway-1",
      ]
    }
    ns = {
      memory = 4
      vcpu   = 1
      nodes = [
        "ns-0",
        "ns-1",
      ]
    }
    controller = {
      memory = 8
      vcpu   = 2
      nodes = [
        "controller-0",
        "controller-1",
        "controller-2",
      ]
    }
    worker = {
      memory = 36
      vcpu   = 4
      network = [
        {
          vlan = "internal"
          if   = "ens3"
          dhcp = true
        },
      ]
      nodes = [
        "worker-0",
        "worker-2",
      ]
      hostdev = [
        "hba",
      ]
    }
  }

  networks = {
    # services - no route to wan
    internal = {
      id        = 1
      network   = "192.168.126.0"
      cidr      = 23
      router    = "192.168.126.240"
      dhcp_pool = "192.168.127.64/26"
      mdns      = true
      mtu       = 9000
    }
    # main
    lan = {
      id        = 90
      network   = "192.168.62.0"
      cidr      = 23
      router    = "192.168.62.240"
      dhcp_pool = "192.168.63.64/26"
      mtu       = 9000
    }
    # gateway conntrack sync and backup route
    sync = {
      id      = 60
      network = "192.168.190.0"
      cidr    = 29
      router  = "192.168.190.6"
      mtu     = 9000
    }
    wan = {
      id = 30
    }
    # internal network on each hypervisor for PXE bootstrap
    metadata = {
      network   = "192.168.224.0"
      cidr      = 23
      dhcp_pool = "192.168.225.64/26"
    }
    # kubernetes internal
    kubernetes = {
      network = "10.244.0.0"
      cidr    = 16
    }
    kubernetes_service = {
      network = "10.96.0.0"
      cidr    = 12
    }
  }

  loadbalancer_pools = {
    kubernetes-internal = {
      network = "192.168.126.64"
      cidr    = 26
    }
  }

  hosts = {
    # Interface name should always start at ens2 and count up
    # libvirt auto assigns interfaces starting at 00:02.0 and
    # increments the slot for each element.
    # Metadata network uses ens2. Start host specific
    # interfaces at ens3.

    # Gateway
    gateway-0 = {
      # Duplicate MAC VRRP (e.g. keepalived) do not work for IP traffic from other VFs on the same NIC.
      # If a MAC exists on another VF on the same hardware, it seems to bypass the switch and get priority
      # over other MACs on the same network even if the VF has no IP.
      network = [
        # Dummy link for management access - don't add a router VIP
        {
          vlan   = "internal"
          ip     = "192.168.127.217"
          router = null
          metric = 2048
          if     = "ens3"
        },
        {
          label = "internal-vip"
          vlan  = "internal"
          if    = "ens4"
          mdns  = false
          vip   = local.networks.internal.router
          # Duplicate this on gateways
          mac = "00-00-5e-00-01-01"
        },
        {
          vlan = "lan"
          if   = "ens5"
          vip  = local.networks.lan.router
          # Duplicate this on gateways
          mac = "00-00-5e-00-01-02"
        },
        {
          vlan = "sync"
          ip   = "192.168.190.1"
          vip  = local.networks.sync.router
          if   = "ens6"
        },
        {
          vlan = "wan"
          if   = "ens7"
          dhcp = true
          # Duplicate this on gateways
          mac = "52-54-00-63-6e-b3"
        },
      ]
    }
    gateway-1 = {
      network = [
        # Dummy link for management access - don't add a router VIP
        {
          vlan   = "internal"
          ip     = "192.168.127.218"
          metric = 2048
          if     = "ens3"
        },
        {
          label = "internal-vip"
          vlan  = "internal"
          if    = "ens4"
          mdns  = false
          vip   = local.networks.internal.router
          # Duplicate this on nodes
          mac = "00-00-5e-00-01-01"
        },
        {
          vlan = "lan"
          if   = "ens5"
          vip  = local.networks.lan.router
          # Duplicate this on nodes
          mac = "00-00-5e-00-01-02"
        },
        {
          vlan = "sync"
          ip   = "192.168.190.2"
          vip  = local.networks.sync.router
          if   = "ens6"
        },
        {
          vlan = "wan"
          if   = "ens7"
          dhcp = true
          # Duplicate this on nodes
          mac = "52-54-00-63-6e-b3"
        },
      ]
    }

    # Nameserver with DHCP
    ns-0 = {
      # This uses the client image so needs more ram disk space
      memory = 8
      network = [
        {
          vlan = "internal"
          ip   = "192.168.127.222"
          vip  = local.services.recursive_dns.vip
          if   = "ens3"
        },
        {
          vlan = "lan"
          ip   = "192.168.63.222"
          if   = "ens4"
        },
      ]
      kea_ha_role = "primary"
    }
    ns-1 = {
      network = [
        {
          vlan = "internal"
          ip   = "192.168.127.223"
          vip  = local.services.recursive_dns.vip
          if   = "ens3"
        },
        {
          vlan = "lan"
          ip   = "192.168.63.223"
          if   = "ens4"
        },
      ]
      kea_ha_role = "secondary"
    }

    # Controllers
    controller-0 = {
      network = [
        {
          vlan = "internal"
          ip   = "192.168.127.219"
          vip  = local.services.kubernetes_apiserver.vip
          if   = "ens3"
        },
      ]
    }
    controller-1 = {
      # This uses the client image so needs more ram disk space
      memory = 10
      network = [
        {
          vlan = "internal"
          ip   = "192.168.127.220"
          vip  = local.services.kubernetes_apiserver.vip
          if   = "ens3"
        },
      ]
    }
    controller-2 = {
      network = [
        {
          vlan = "internal"
          ip   = "192.168.127.221"
          vip  = local.services.kubernetes_apiserver.vip
          if   = "ens3"
        },
      ]
    }

    # Workers
    # Network config is same for all hosts
    worker-0 = {
      disks = [
        {
          device = "/dev/disk/by-id/ata-Samsung_SSD_860_QVO_1TB_S4PGNF0M410395Z"
          partitions = [
            {
              label     = "localcache"
              start_mib = 0
              size_mib  = 0
            },
          ]
        },
      ]
      luks = [
        {
          label  = "localcache"
          device = "/dev/disk/by-partlabel/localcache"
        },
      ]
      # Defaults:
      # format = "xfs"
      # wipe_filesystem = false
      filesystems = [
        {
          label      = "localcache"
          device     = "/dev/disk/by-id/dm-name-localcache"
          mount_path = "/var/lib/kubelet/pv"
        },
        {
          label      = "20162AA4B92B"
          device     = "/dev/disk/by-id/ata-Micron_5210_MTFDDAK7T6QDE_20162AA4B92B"
          mount_path = "/var/minio0/0"
          options = [
            "noatime",
            "nodiratime",
            "discard",
          ]
        },
        {
          label      = "20162AA4B943"
          device     = "/dev/disk/by-id/ata-Micron_5210_MTFDDAK7T6QDE_20162AA4B943"
          mount_path = "/var/minio0/1"
          options = [
            "noatime",
            "nodiratime",
            "discard",
          ]
        },
        {
          label      = "20162AA4BFFD"
          device     = "/dev/disk/by-id/ata-Micron_5210_MTFDDAK7T6QDE_20162AA4BFFD"
          mount_path = "/var/minio0/2"
          options = [
            "noatime",
            "nodiratime",
            "discard",
          ]
        },
        {
          label      = "20162AA4C02F"
          device     = "/dev/disk/by-id/ata-Micron_5210_MTFDDAK7T6QDE_20162AA4C02F"
          mount_path = "/var/minio0/3"
          options = [
            "noatime",
            "nodiratime",
            "discard",
          ]
        },
        {
          label      = "20162AA4C311"
          device     = "/dev/disk/by-id/ata-Micron_5210_MTFDDAK7T6QDE_20162AA4C311"
          mount_path = "/var/minio0/4"
          options = [
            "noatime",
            "nodiratime",
            "discard",
          ]
        },
        {
          label      = "20162AA4C4CB"
          device     = "/dev/disk/by-id/ata-Micron_5210_MTFDDAK7T6QDE_20162AA4C4CB"
          mount_path = "/var/minio0/5"
          options = [
            "noatime",
            "nodiratime",
            "discard",
          ]
        },
        {
          label      = "20242A9E3D2A"
          device     = "/dev/disk/by-id/ata-Micron_5210_MTFDDAK7T6QDE_20242A9E3D2A"
          mount_path = "/var/minio0/6"
          options = [
            "noatime",
            "nodiratime",
            "discard",
          ]
        },
        {
          label      = "20242BABB479"
          device     = "/dev/disk/by-id/ata-Micron_5210_MTFDDAK7T6QDE_20242BABB479"
          mount_path = "/var/minio0/7"
          options = [
            "noatime",
            "nodiratime",
            "discard",
          ]
        },
      ]
      node_labels = {
        "minio-data"        = "true"
        "openebs.io/engine" = "mayastor"
      }
    }
    worker-2 = {
      node_labels = {
        "openebs.io/engine" = "mayastor"
      }
    }

    # KVM
    kvm-0 = {
      hwif = [
        {
          label = "pf0"
          if    = "en-pf0"
          mac   = "3c-fd-fe-9e-ac-70"
        },
        {
          label = "pf1"
          if    = "en-pf1"
          mac   = "3c-fd-fe-9e-ac-72"
        },
      ]
      network = [
        {
          vlan = "internal"
          if   = "en-int"
          ip   = "192.168.127.251"
          dhcp = true
          hwif = "pf0"
        },
      ]
      ## hypervisor boot image is copied with coreos-installer to strip
      ## out ignition and re-used to boot VMs
      libvirt_domains = [
        {
          node = "gateway-1"
          # This cannot run on the same SRIOV pf as other VMs
          hwif = "pf1"
        },
        {
          node = "ns-1"
          hwif = "pf0"
        },
        {
          node = "controller-0"
          hwif = "pf0"
        },
        {
          node = "worker-0"
          hwif = "pf0"
        },
      ]
      dev = {
        # HBA addon card
        hba = {
          domain   = "0x0000"
          bus      = "0x01"
          slot     = "0x00"
          function = "0x0"
          rom      = "/etc/libvirt/boot/SAS9300_8i_IT.bin"
        }
      }
    }
    kvm-2 = {
      hwif = [
        {
          label = "pf0"
          if    = "en-pf0"
          mac   = "3c-ec-ef-45-96-e6"
        },
        {
          label = "pf1"
          if    = "en-pf1"
          mac   = "3c-ec-ef-45-96-e7"
        },
        {
          label = "pf2"
          if    = "en-pf2"
          mac   = "3c-ec-ef-45-96-e8"
        },
        {
          label = "pf3"
          if    = "en-pf3"
          mac   = "3c-ec-ef-45-96-e9"
        },
      ]
      network = [
        {
          vlan = "internal"
          if   = "en-int"
          ip   = "192.168.127.250"
          dhcp = true
          hwif = "pf0"
        },
      ]
      ## hypervisor boot image is copied with coreos-installer to strip
      ## out ignition and re-used to boot VMs
      libvirt_domains = [
        {
          node = "gateway-0"
          # This cannot run on the same SRIOV pf as other VMs
          hwif = "pf1"
        },
        {
          node = "controller-2"
          hwif = "pf0"
        },
        {
          node = "worker-2"
          hwif = "pf2"
        },
      ]
    }

    # client devices
    client-0 = {
      hwif = [
        {
          label = "pf0"
          if    = "en-pf0"
          mac   = "f4-52-14-7b-53-80"
        },
      ]
      network = [
        {
          vlan = "internal"
          if   = "en-int"
          ip   = "192.168.127.253"
          dhcp = true
          hwif = "pf0"
        },
      ]
      ## hypervisor boot image is copied with coreos-installer to strip
      ## out ignition and re-used to boot VMs
      libvirt_domains = [
        {
          node = "ns-0"
          hwif = "pf0"
        },
        {
          node = "controller-1"
          hwif = "pf0"
        },
      ]
      disks = [
        {
          device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_1TB_S5H9NS0N986704R"
          partitions = [
            {
              label     = "localhome"
              start_mib = 0
              size_mib  = 0
            },
          ]
        },
      ]
      luks = [
        {
          label  = "localhome"
          device = "/dev/disk/by-partlabel/localhome"
        },
      ]
      filesystems = [
        {
          label      = "localhome"
          device     = "/dev/disk/by-id/dm-name-localhome"
          mount_path = "/var/lib/kubelet/pv"
        },
      ]
    }

    # unmanaged hardware
    switch-0 = {
      network = [
        {
          vlan = "internal"
          ip   = "192.168.127.60"
          mac  = "50-c7-bf-60-78-22"
        },
      ]
    }
    ipmi-0 = {
      network = [
        {
          vlan = "internal"
          ip   = "192.168.127.61"
          mac  = "ac-1f-6b-ae-76-60"
        },
      ]
    }
    ipmi-2 = {
      network = [
        {
          vlan = "internal"
          ip   = "192.168.127.63"
          mac  = "3c-ec-ef-45-97-77"
        }
      ]
    }
  }

  # similar to guests filter
  # control which configs are rendered on local matchbox
  local_renderer_hosts_include = [
    "kvm-0",
    "kvm-2",
    "client-0",
  ]
}
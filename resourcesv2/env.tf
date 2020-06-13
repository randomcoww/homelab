locals {
  desktop_user = "randomcoww"
  # Default user for CoreOS
  user = "core"
  mtu  = 9000

  # kubernetes
  kubernetes_cluster_name = "default-cluster-2005"
  aws_region              = "us-west-2"

  # etcd backup
  s3_etcd_backup_bucket = "randomcoww-etcd-backup"

  # secrets store
  # format:
  # ---
  # service1:
  #   service1key: service1value
  #   ...
  # service2:
  #   service2key: service2value
  # ...
  s3_secrets_bucket = "randomcoww-secrets"
  s3_secrets_key    = "secrets.yaml"

  templates_path = "${path.module}/../templates"
  # kubelet image is used for static pods and does not need to match the kubernetes version
  # hyperkube is used for the worker kubelet and should match the version
  container_images = {
    kubelet                 = "docker.io/randomcoww/kubernetes:kubelet-v1.18.3"
    kube_apiserver          = "docker.io/randomcoww/kubernetes:kube-master-v1.18.3"
    kube_controller_manager = "docker.io/randomcoww/kubernetes:kube-master-v1.18.3"
    kube_scheduler          = "docker.io/randomcoww/kubernetes:kube-master-v1.18.3"
    hyperkube               = "docker.io/randomcoww/kubernetes:kubelet-v1.18.3"
    kube_proxy              = "docker.io/randomcoww/kubernetes:kube-proxy-v1.18.3"
    etcd_wrapper            = "docker.io/randomcoww/etcd-wrapper:v0.2.1"
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
  }

  kernel_image = "images/vmlinuz"
  initrd_images = [
    "images/initramfs.img"
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
    kubernetes_cluster = "cluster.internal"
    mdns               = "local"
  }

  networks = {
    # management
    main = {
      id        = 1
      network   = "192.168.126.0"
      cidr      = 23
      router    = "192.168.126.240"
      dhcp_pool = "192.168.127.64/26"
      br_if     = "en-main"
    }
    lan = {
      id        = 90
      network   = "192.168.62.0"
      cidr      = 23
      router    = "192.168.62.240"
      dhcp_pool = "192.168.63.64/26"
      br_if     = "en-lan"
    }
    # gateway state sync
    sync = {
      id      = 60
      network = "192.168.190.0"
      router  = "192.168.190.6"
      cidr    = 29
      br_if   = "en-sync"
    }
    wan = {
      id    = 30
      br_if = "en-wan"
    }
    # internal network on each hypervisor for PXE bootstrap
    int = {
      network   = "192.168.224.0"
      cidr      = 23
      dhcp_pool = "192.168.225.64/26"
      br_if     = "en-int"
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
    kubernetes = {
      network = "192.168.126.64"
      cidr    = 26
    }
  }

  components = {
    common_guests = {
      nodes = [
        "gateway-0",
        "gateway-1",
        "controller-0",
        "controller-1",
        "controller-2",
        "worker-0",
        "worker-1",
        "test-0",
      ]
      libvirt_template = "${local.templates_path}/libvirt/container_linux.xml.tmpl"
    }
    ssh = {
      nodes = [
        "gateway-0",
        "gateway-1",
        "controller-0",
        "controller-1",
        "controller-2",
        "worker-0",
        "worker-1",
        "kvm-0",
        "kvm-1",
        "test-0",
        "desktop",
      ]
      templates = [
        "${local.templates_path}/ignition/ssh.ign.tmpl",
      ]
    }
    traefik_tls = {
      nodes = [
        "desktop",
      ]
      templates = [
        "${local.templates_path}/ignition/internal_tls.ign.tmpl",
      ]
    }
    wireguard_client = {
      nodes = [
      ]
      templates = [
        "${local.templates_path}/ignition/wireguard_client.ign.tmpl",
      ]
    }
    static_pod_logging = {
      nodes = [
        "gateway-0",
        "gateway-1",
        "controller-0",
        "controller-1",
        "controller-2",
      ]
      templates = [
        "${local.templates_path}/ignition/static_pod_logging.ign.tmpl",
      ]
    }
    gateway = {
      nodes = [
        "gateway-0",
        "gateway-1",
      ]
      templates = [
        "${local.templates_path}/ignition/gateway.ign.tmpl",
        "${local.templates_path}/ignition/base.ign.tmpl",
        "${local.templates_path}/ignition/containerd.ign.tmpl",
        "${local.templates_path}/ignition/user.ign.tmpl",
      ]
    }
    controller = {
      nodes = [
        "controller-0",
        "controller-1",
        "controller-2",
      ]
      templates = [
        "${local.templates_path}/ignition/controller.ign.tmpl",
        "${local.templates_path}/ignition/base.ign.tmpl",
        "${local.templates_path}/ignition/containerd.ign.tmpl",
        "${local.templates_path}/ignition/user.ign.tmpl",
      ]
    }
    worker = {
      nodes = [
        "worker-0",
        "worker-1",
      ]
      templates = [
        "${local.templates_path}/ignition/worker.ign.tmpl",
        "${local.templates_path}/ignition/base.ign.tmpl",
        "${local.templates_path}/ignition/storage.ign.tmpl",
        "${local.templates_path}/ignition/containerd.ign.tmpl",
        "${local.templates_path}/ignition/user.ign.tmpl",
      ]
    }
    test = {
      nodes = [
        "test-0"
      ]
      templates = [
        "${local.templates_path}/ignition/test.ign.tmpl",
        "${local.templates_path}/ignition/base.ign.tmpl",
        "${local.templates_path}/ignition/storage.ign.tmpl",
        "${local.templates_path}/ignition/containerd.ign.tmpl",
        "${local.templates_path}/ignition/user.ign.tmpl",
      ]
    }
    kvm = {
      nodes = [
        "kvm-0",
        "kvm-1",
      ]
      templates = [
        "${local.templates_path}/ignition/kvm.ign.tmpl",
        "${local.templates_path}/ignition/vlan_network.ign.tmpl",
        "${local.templates_path}/ignition/base.ign.tmpl",
        "${local.templates_path}/ignition/user.ign.tmpl",
      ]
    }
    desktop = {
      nodes = [
        "desktop",
      ]
      templates = [
        "${local.templates_path}/ignition/desktop.ign.tmpl",
        "${local.templates_path}/ignition/vlan_network.ign.tmpl",
        "${local.templates_path}/ignition/base.ign.tmpl",
        "${local.templates_path}/ignition/storage.ign.tmpl",
        "${local.templates_path}/ignition/user.ign.tmpl",
      ]
    }
  }

  addon_templates = {
    bootstrap        = "${local.templates_path}/manifest/bootstrap.yaml.tmpl"
    kube-proxy       = "${local.templates_path}/manifest/kube_proxy.yaml.tmpl"
    kapprover        = "${local.templates_path}/manifest/kapprover.yaml.tmpl"
    flannel          = "${local.templates_path}/manifest/flannel.yaml.tmpl"
    coredns          = "${local.templates_path}/manifest/coredns.yaml.tmpl"
    secret           = "${local.templates_path}/manifest/secret.yaml.tmpl"
    metallb-network  = "${local.templates_path}/manifest/metallb_network.yaml.tmpl"
    kubeconfig-admin = "${local.templates_path}/manifest/kubeconfig_admin.yaml.tmpl"
    loki-lb-service  = "${local.templates_path}/manifest/loki_lb_service.yaml.tmpl"
  }

  hosts = {
    # gateway
    gateway-0 = {
      memory = 3
      vcpu   = 1
      network = [
        {
          network = "main"
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
          network = "wan"
          if      = "eth3"
          mac     = "52-54-00-63-6e-b3"
        },
        {
          network   = "int"
          if        = "eth4"
          mac       = "52-54-00-1a-61-2a"
          bootorder = 1
        }
      ]
      kea_ha_role = "primary"
    }
    gateway-1 = {
      memory = 3
      vcpu   = 1
      network = [
        {
          network = "main"
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
          network = "wan"
          if      = "eth3"
          mac     = "52-54-00-63-6e-b3"
        },
        {
          network   = "int"
          if        = "eth4"
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
      network = [
        {
          network = "main"
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
      network = [
        {
          network = "main"
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
      network = [
        {
          network = "main"
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
      memory = 48
      vcpu   = 4
      network = [
        {
          network = "main"
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
          source = "/dev/disk/by-id/ata-Samsung_SSD_860_QVO_1TB_S4PGNF0M414895K"
          target = "vda"
          device = "/dev/vda"
        },
      ]
    }
    worker-1 = {
      memory = 48
      vcpu   = 4
      network = [
        {
          network = "main"
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
          source = "/dev/disk/by-id/ata-Samsung_SSD_860_QVO_1TB_S4PGNF0M410395Z"
          target = "vda"
          device = "/dev/vda"
        }
      ]
    }

    # Test instances
    test-0 = {
      memory = 4
      vcpu   = 2
      network = [
        {
          network = "main"
          if      = "eth0"
        },
        {
          network   = "int"
          if        = "eth1"
          mac       = "52-54-00-1a-61-3a"
          bootorder = 1
        }
      ]
      disk = [
      ]
    }

    # KVM
    kvm-0 = {
      network = [
        {
          alias = "hw"
          mac   = "00-1b-21-bc-4c-16"
        },
        {
          network = "main"
          ip      = "192.168.127.251"
        }
      ]
      guests = [
        "gateway-0",
        "controller-0",
        "controller-1",
        "controller-2",
        "worker-0",
      ]
      ## hypervisor boot image is copied with coreos-installer to strip
      ## out ignition and re-used to boot VMs
      image_device = "/dev/disk/by-label/fedora-coreos-32"
    }
    kvm-1 = {
      network = [
        {
          alias = "hw"
          mac   = "00-1b-21-bc-67-c6"
        },
        {
          network = "main"
          ip      = "192.168.127.252"
        }
      ]
      guests = [
        "gateway-1",
        "controller-0",
        "controller-1",
        "controller-2",
        "worker-1",
      ]
      ## hypervisor boot image is copied with coreos-installer to strip
      ## out ignition and re-used to boot VMs
      image_device = "/dev/disk/by-label/fedora-coreos-32"
    }

    # desktop
    desktop = {
      network = [
        {
          alias = "hw"
          mac   = "f8-f2-1e-1e-3c-40"
        },
        {
          network = "main"
          ip      = "192.168.127.253"
        }
      ]
      disk = [
        {
          device     = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_250GB_S465NB0K598517N-part1"
          mount_path = "/var/home/${local.desktop_user}"
        }
      ]
      ## hypervisor boot image is copied with coreos-installer to strip
      ## out ignition and re-used to boot VMs
      image_device = "/dev/disk/by-label/fedora-silverblue-32"
    }
  }

  # similar to guests filter
  # control which configs are rendered on local matchbox
  local_renderer_hosts_include = [
    "kvm-0",
    "kvm-1",
    # password bcrypt included with desktop causes all ignition configs to get regenerated each run
    "desktop",
  ]

  host_network_by_type = {
    for k in keys(local.hosts) :
    k => {
      for n in local.hosts[k].network :
      lookup(n, "alias", lookup(n, "network", "placeholder")) => n
    }
  }
}
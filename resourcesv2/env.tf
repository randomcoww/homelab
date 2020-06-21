locals {
  templates_path = "${path.module}/../templates"

  # Default user for CoreOS
  user = "core"
  # Desktop env user
  desktop_user = "randomcoww"

  # Set all MTU
  mtu = 9000

  # S3 backup for etcd
  # path is based on the cluster name
  aws_region              = "us-west-2"
  s3_etcd_backup_bucket   = "randomcoww-etcd-backup"
  kubernetes_cluster_name = "default-cluster-2005"

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
    external_dns            = "registry.opensource.zalan.do/teapot/external-dns:latest"
    kapprover               = "docker.io/randomcoww/kapprover:v0.0.4"
    kea                     = "docker.io/randomcoww/kea:1.6.2"
    conntrackd              = "docker.io/randomcoww/conntrackd:latest"
    promtail                = "docker.io/randomcoww/promtail:v1.4.1"
    matchbox                = "quay.io/poseidon/matchbox:latest"
  }

  boot_disk_label = "fedora-coreos-32"
  kernel_image    = "images/vmlinuz"
  initrd_images = [
    "images/initramfs.img",
  ]
  kernel_params = [
    "console=hvc0",
    "rd.neednet=1",
    "ignition.firstboot",
    "ignition.platform.id=metal",
    # "net.ifnames=0",
    # "biosdevname=0",
    "systemd.unified_cgroup_hierarchy=0",
    "coreos.liveiso=${local.boot_disk_label}",
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

  components = {
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
      ignition_templates = [
        "${local.templates_path}/ignition/ssh.ign.tmpl",
      ]
    }
    traefik_tls = {
      nodes = [
        "desktop",
      ]
      ignition_templates = [
        "${local.templates_path}/ignition/internal_tls.ign.tmpl",
      ]
    }
    wireguard_client = {
      nodes = [
      ]
      ignition_templates = [
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
      ignition_templates = [
        "${local.templates_path}/ignition/static_pod_logging.ign.tmpl",
      ]
    }
    gateway = {
      nodes = [
        "gateway-0",
        "gateway-1",
      ]
      ignition_templates = [
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
      ignition_templates = [
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
      ignition_templates = [
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
      ignition_templates = [
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
      ignition_templates = [
        "${local.templates_path}/ignition/kvm.ign.tmpl",
        "${local.templates_path}/ignition/sriov_network.ign.tmpl",
        "${local.templates_path}/ignition/base.ign.tmpl",
        "${local.templates_path}/ignition/user.ign.tmpl",
      ]
    }
    desktop = {
      nodes = [
        "desktop",
      ]
      ignition_templates = [
        "${local.templates_path}/ignition/desktop.ign.tmpl",
        "${local.templates_path}/ignition/sriov_network.ign.tmpl",
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

  libvirt_domain_templates = {
    coreos = "${local.templates_path}/libvirt/coreos.xml.tmpl"
  }
  libvirt_network_templates = {
    sriov = "${local.templates_path}/libvirt/hostdev_network.xml.tmpl"
  }

  networks = {
    # management
    main = {
      id              = 1
      network         = "192.168.126.0"
      cidr            = 23
      router          = "192.168.126.240"
      dhcp_pool       = "192.168.127.64/26"
      libvirt_network = "sriov"
    }
    lan = {
      id              = 90
      network         = "192.168.62.0"
      cidr            = 23
      router          = "192.168.62.240"
      dhcp_pool       = "192.168.63.64/26"
      libvirt_network = "sriov"
    }
    # gateway state sync
    sync = {
      id              = 60
      network         = "192.168.190.0"
      cidr            = 29
      router          = "192.168.190.6"
      libvirt_network = "sriov"
    }
    wan = {
      id              = 30
      libvirt_network = "sriov"
    }
    # internal network on each hypervisor for PXE bootstrap
    int = {
      network   = "192.168.224.0"
      cidr      = 23
      dhcp_pool = "192.168.225.64/26"
      bootorder = 1
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

  hosts = {
    # gateway
    gateway-0 = {
      memory = 3
      vcpu   = 1
      # interface name should always start at ens2 and count up
      # libvirt auto assigns interfaces starting at 00:02.0 and
      # increments the slot for each element
      network = [
        {
          label = "int"
          if    = "ens2"
          mac   = "52-54-00-1a-61-2a"
        },
        {
          label = "main"
          ip    = "192.168.127.217"
          if    = "ens3"
        },
        {
          label = "lan"
          ip    = "192.168.63.217"
          if    = "ens4"
        },
        {
          label = "sync"
          ip    = "192.168.190.1"
          if    = "ens5"
        },
        {
          label = "wan"
          if    = "ens6"
          mac   = "52-54-00-63-6e-b3"
        }
      ]
      kea_ha_role = "primary"
    }
    gateway-1 = {
      memory = 3
      vcpu   = 1
      network = [
        {
          label = "int"
          if    = "ens2"
          mac   = "52-54-00-1a-61-2b"
        },
        {
          label = "main"
          ip    = "192.168.127.218"
          if    = "ens3"
        },
        {
          label = "lan"
          ip    = "192.168.63.218"
          if    = "ens4"
        },
        {
          label = "sync"
          ip    = "192.168.190.2"
          if    = "ens5"
        },
        {
          label = "wan"
          if    = "ens6"
          mac   = "52-54-00-63-6e-b3"
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
          label = "int"
          if    = "ens2"
          mac   = "52-54-00-1a-61-0a"
        },
        {
          label = "main"
          ip    = "192.168.127.219"
          if    = "ens3"
        }
      ]
    }
    controller-1 = {
      memory = 4
      vcpu   = 2
      network = [
        {
          label = "int"
          if    = "ens2"
          mac   = "52-54-00-1a-61-0b"
        },
        {
          label = "main"
          ip    = "192.168.127.220"
          if    = "ens3"
        }
      ]
    }
    controller-2 = {
      memory = 4
      vcpu   = 2
      network = [
        {
          label = "int"
          if    = "ens2"
          mac   = "52-54-00-1a-61-0c"
        },
        {
          label = "main"
          ip    = "192.168.127.221"
          if    = "ens3"
        }
      ]
    }

    # workers
    worker-0 = {
      memory = 48
      vcpu   = 4
      network = [
        {
          label = "int"
          if    = "ens2"
          mac   = "52-54-00-1a-61-1a"
        },
        {
          label = "main"
          if    = "ens3"
        }
      ]
      hostdev = [
        {
          domain   = "0x0000"
          bus      = "0x02"
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
          target = "sdb"
        },
      ]
    }
    worker-1 = {
      memory = 48
      vcpu   = 4
      network = [
        {
          label = "int"
          if    = "ens2"
          mac   = "52-54-00-1a-61-1b"
        },
        {
          label = "main"
          if    = "ens3"
        }
      ]
      hostdev = [
        {
          domain   = "0x0000"
          bus      = "0x02"
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
          target = "sdb"
        }
      ]
    }

    # Test instances
    test-0 = {
      memory = 4
      vcpu   = 2
      network = [
        {
          label = "int"
          if    = "ens2"
          mac   = "52-54-00-1a-61-3a"
        },
        {
          label = "main"
          if    = "ens3"
        }
      ]
    }

    # KVM
    kvm-0 = {
      network = [
        {
          mac                = "00-1b-21-bc-4c-16"
          if                 = "en-pf"
          libvirt_network_pf = "sriov"
        },
        {
          label = "main"
          if    = "en-main"
          ip    = "192.168.127.251"
        },
        {
          label = "int"
          if    = "en-int"
          ip    = local.services.renderer.vip
        }
      ]
      ## hypervisor boot image is copied with coreos-installer to strip
      ## out ignition and re-used to boot VMs
      libvirt_domains = {
        coreos = [
          "gateway-0",
          "controller-0",
          "controller-1",
          "controller-2",
          "worker-0",
        ]
      }
      boot_image_device     = "/dev/disk/by-label/${local.boot_disk_label}"
      boot_image_mount_path = "/etc/libvirt/boot/${local.boot_disk_label}.iso"
    }
    kvm-1 = {
      network = [
        {
          mac                = "00-1b-21-bc-67-c6"
          if                 = "en-pf"
          libvirt_network_pf = "sriov"
        },
        {
          label = "main"
          if    = "en-main"
          ip    = "192.168.127.252"
        },
        {
          label = "int"
          if    = "en-int"
          ip    = local.services.renderer.vip
        }
      ]
      ## hypervisor boot image is copied with coreos-installer to strip
      ## out ignition and re-used to boot VMs
      libvirt_domains = {
        coreos = [
          "gateway-1",
          "controller-0",
          "controller-1",
          "controller-2",
          "worker-1",
          "test-0",
        ]
      }
      boot_image_device     = "/dev/disk/by-label/${local.boot_disk_label}"
      boot_image_mount_path = "/etc/libvirt/boot/${local.boot_disk_label}.iso"
    }

    # desktop
    desktop = {
      network = [
        {
          mac = "f8-f2-1e-1e-3c-40"
          if  = "en-pf"
        },
        {
          label = "main"
          if    = "en-main"
          ip    = "192.168.127.253"
        }
      ]
      disk = [
        {
          device     = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_250GB_S465NB0K598517N-part1"
          mount_path = "/var/home/${local.desktop_user}"
        }
      ]
    }
    laptop = {
      network = [
        {
          mac = "08-0e-01-cf-ef-aa"
          if  = "en-pf"
        },
        {
          label = "main"
          if    = "en-main"
          ip    = "192.168.127.254"
        }
      ]
      disk = [
        {
          device     = "/dev/disk/by-id/ata-SAMSUNG_SSD_830_Series_SOXYNEAC720618-part1"
          mount_path = "/var/home/${local.desktop_user}"
        }
      ]
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
}
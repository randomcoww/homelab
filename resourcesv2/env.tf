locals {
  templates_path = "${path.module}/../templates"

  # Default user for CoreOS and Silverblue
  user        = "core"
  client_user = "randomcoww"
  # Desktop env user. This affects the persistent home directory.
  # S3 backup for etcd
  # path is based on the cluster name
  aws_region              = "us-west-2"
  s3_etcd_backup_bucket   = "randomcoww-etcd-backup"
  kubernetes_cluster_name = "default-cluster-2007-1"
  # kubelet image is used for static pods and does not need to match the kubernetes version
  # hyperkube is used for the worker kubelet and should match the version
  container_images = {
    kubelet                 = "docker.io/randomcoww/kubernetes:kubelet-v1.18.8"
    kube_apiserver          = "docker.io/randomcoww/kubernetes:kube-master-v1.18.8"
    kube_controller_manager = "docker.io/randomcoww/kubernetes:kube-master-v1.18.8"
    kube_scheduler          = "docker.io/randomcoww/kubernetes:kube-master-v1.18.8"
    hyperkube               = "docker.io/randomcoww/kubernetes:kubelet-v1.18.8"
    kube_proxy              = "docker.io/randomcoww/kubernetes:kube-proxy-v1.18.8"
    etcd_wrapper            = "docker.io/randomcoww/etcd-wrapper:v0.2.1"
    etcd                    = "docker.io/randomcoww/etcd:v3.4.10"
    flannel                 = "docker.io/randomcoww/flannel:latest"
    keepalived              = "docker.io/randomcoww/keepalived:latest"
    cni_plugins             = "docker.io/randomcoww/cni-plugins:v0.8.6"
    coredns                 = "docker.io/coredns/coredns:1.7.0"
    external_dns            = "registry.opensource.zalan.do/teapot/external-dns:latest"
    kapprover               = "docker.io/randomcoww/kapprover:v0.0.4"
    kea                     = "docker.io/randomcoww/kea:1.6.2"
    conntrackd              = "docker.io/randomcoww/conntrackd:latest"
    promtail                = "docker.io/randomcoww/promtail:v1.5.0"
    matchbox                = "quay.io/poseidon/matchbox:latest"
  }

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
    # coreos hypervisor
    hypervisor = {
      nodes = [
        "kvm-0",
        "kvm-1",
      ]
      ignition_templates = [
        "${local.templates_path}/ignition/base.ign.tmpl",
        "${local.templates_path}/ignition/base_server.ign.tmpl",
        "${local.templates_path}/ignition/base_systemd_networkd.ign.tmpl",
        "${local.templates_path}/ignition/vlan_network.ign.tmpl",
        "${local.templates_path}/ignition/hypervisor.ign.tmpl",
      ]
      libvirt_network_template = "${local.templates_path}/libvirt/hostdev_network.xml.tmpl"
      pxe_image_mount_path     = "/run/media/iso/images/pxeboot"
    }
    # coreos VMs
    vm = {
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
      ignition_templates = [
        "${local.templates_path}/ignition/base.ign.tmpl",
        "${local.templates_path}/ignition/base_server.ign.tmpl",
        "${local.templates_path}/ignition/base_systemd_networkd.ign.tmpl",
        "${local.templates_path}/ignition/general_network.ign.tmpl",
      ]
      libvirt_domain_template = "${local.templates_path}/libvirt/coreos.xml.tmpl"
      kernel_image            = "vmlinuz"
      initrd_images = [
        "initrd.img",
        "rootfs.img",
      ]
      kernel_params = [
        "console=hvc0",
        "rd.neednet=1",
        "ignition.firstboot",
        "ignition.platform.id=metal",
        "systemd.unified_cgroup_hierarchy=0",
      ]
    }
    # silverblue (gnome) desktop with networkmanager
    client = {
      nodes = [
        "client-0",
      ]
      client_user     = local.client_user
      client_user_uid = 10000
      ignition_templates = [
        "${local.templates_path}/ignition/base.ign.tmpl",
        "${local.templates_path}/ignition/base_client.ign.tmpl",
        "${local.templates_path}/ignition/storage.ign.tmpl",
        "${local.templates_path}/ignition/desktop_env.ign.tmpl",
        "${local.templates_path}/ignition/base_network_manager.ign.tmpl",
        # Enable either pulseaudio server or client
        "${local.templates_path}/ignition/pulseaudio_server.ign.tmpl",
        # "${local.templates_path}/ignition/pulseaudio_client.ign.tmpl",
        # "${local.templates_path}/ignition/swap.ign.tmpl",
      ]
    }
    # server certs for SSH CA
    ssh_server = {
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
      ]
      ignition_templates = [
        "${local.templates_path}/ignition/ssh_server.ign.tmpl",
      ]
    }
    ssh_client = {
      nodes = [
        "client-0"
      ]
      ignition_templates = [
        "${local.templates_path}/ignition/ssh_client.ign.tmpl",
      ]
    }
    # cert for fuzzybunny.internal
    traefik_tls = {
      nodes = [
        "client-0",
      ]
      ignition_templates = [
        "${local.templates_path}/ignition/internal_tls.ign.tmpl",
      ]
    }
    # promtail to push logs to loki (non kubernetes containerd hosts)
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

    # host specific
    gateway = {
      nodes = [
        "gateway-0",
        "gateway-1",
      ]
      ignition_templates = [
        "${local.templates_path}/ignition/gateway.ign.tmpl",
        "${local.templates_path}/ignition/containerd.ign.tmpl",
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
        "${local.templates_path}/ignition/containerd.ign.tmpl",
      ]
    }
    worker = {
      nodes = [
        "worker-0",
        "worker-1",
      ]
      ignition_templates = [
        "${local.templates_path}/ignition/worker.ign.tmpl",
        "${local.templates_path}/ignition/storage.ign.tmpl",
        "${local.templates_path}/ignition/containerd.ign.tmpl",
      ]
    }
    test = {
      nodes = [
        "test-0"
      ]
      ignition_templates = [
        "${local.templates_path}/ignition/test.ign.tmpl",
        "${local.templates_path}/ignition/storage.ign.tmpl",
        "${local.templates_path}/ignition/containerd.ign.tmpl",
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

  networks = {
    # management
    main = {
      id        = 1
      network   = "192.168.126.0"
      cidr      = 23
      router    = "192.168.126.240"
      dhcp_pool = "192.168.127.64/26"
      mdns      = true
      mtu       = 9000
    }
    lan = {
      id        = 90
      network   = "192.168.62.0"
      cidr      = 23
      router    = "192.168.62.240"
      dhcp_pool = "192.168.63.64/26"
      mtu       = 9000
    }
    # gateway state sync
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
    int = {
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
          label = "main"
          ip    = "192.168.127.217"
          if    = "ens3"
        },
        {
          label = "lan"
          ip    = "192.168.63.217"
          if    = "ens4"
          mac   = "52-54-00-63-dd-a1"
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
          dhcp  = true
        }
      ]
      metadata = {
        label = "int"
        if    = "ens2"
        mac   = "52-54-00-1a-61-2a"
      }
      kea_ha_role = "primary"
    }
    gateway-1 = {
      memory = 3
      vcpu   = 1
      network = [
        {
          label = "main"
          ip    = "192.168.127.218"
          if    = "ens3"
        },
        {
          label = "lan"
          ip    = "192.168.63.218"
          if    = "ens4"
          mac   = "52-54-00-63-dd-a1"
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
          dhcp  = true
        }
      ]
      metadata = {
        label = "int"
        if    = "ens2"
        mac   = "52-54-00-1a-61-2b"
      }
      kea_ha_role = "secondary"
    }

    # controllers
    controller-0 = {
      memory = 5
      vcpu   = 2
      network = [
        {
          label = "main"
          ip    = "192.168.127.219"
          if    = "ens3"
          dhcp  = true
        }
      ]
      metadata = {
        label = "int"
        if    = "ens2"
        mac   = "52-54-00-1a-61-0a"
      }
    }
    controller-1 = {
      memory = 5
      vcpu   = 2
      network = [
        {
          label = "main"
          ip    = "192.168.127.220"
          if    = "ens3"
          dhcp  = true
        }
      ]
      metadata = {
        label = "int"
        if    = "ens2"
        mac   = "52-54-00-1a-61-0b"
      }
    }
    controller-2 = {
      memory = 5
      vcpu   = 2
      network = [
        {
          label = "main"
          ip    = "192.168.127.221"
          if    = "ens3"
          dhcp  = true
        }
      ]
      metadata = {
        label = "int"
        if    = "ens2"
        mac   = "52-54-00-1a-61-0c"
      }
    }

    # workers
    worker-0 = {
      memory = 44
      vcpu   = 6
      network = [
        {
          label = "main"
          if    = "ens3"
          dhcp  = true
        }
      ]
      metadata = {
        label = "int"
        if    = "ens2"
        mac   = "52-54-00-1a-61-1a"
      }
      hostdev = [
        "chipset-sata",
        "hba"
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
          device     = "/dev/disk/by-id/ata-Samsung_SSD_860_QVO_1TB_S4PGNF0M414895K"
          mount_path = "/var/lib/kubelet/pv"
        },
      ]
    }
    worker-1 = {
      memory = 44
      vcpu   = 6
      network = [
        {
          label = "main"
          if    = "ens3"
          dhcp  = true
        }
      ]
      metadata = {
        label = "int"
        if    = "ens2"
        mac   = "52-54-00-1a-61-1b"
      }
      hostdev = [
        "chipset-sata",
        "hba"
      ]
      disk = [
        {
          device     = "/dev/disk/by-id/ata-Samsung_SSD_860_QVO_1TB_S4PGNF0M410395Z"
          mount_path = "/var/lib/kubelet/pv"
        },
      ]
    }

    # Test instances
    test-0 = {
      memory = 4
      vcpu   = 2
      network = [
        {
          label = "main"
          if    = "ens3"
          dhcp  = true
        }
      ]
      metadata = {
        label = "int"
        if    = "ens2"
        mac   = "52-54-00-1a-61-3a"
      }
    }

    # KVM
    kvm-0 = {
      hwif = [
        {
          label  = "pf0"
          if     = "en-pf0"
          mac    = "00-1b-21-bc-4c-16"
          numvfs = 15
        },
      ]
      network = [
        {
          label = "main"
          if    = "en-main"
          ip    = "192.168.127.251"
          dhcp  = true
          hwif  = "pf0"
        }
      ]
      metadata = {
        label = "int"
        if    = "en-int"
        ip    = local.services.renderer.vip
      }
      ## hypervisorf boot image is copied with coreos-installer to strip
      ## out ignition and re-used to boot VMs
      libvirt_domains = [
        {
          node = "gateway-0",
          hwif = "pf0",
        },
        {
          node = "controller-0",
          hwif = "pf0",
        },
        {
          node = "controller-1",
          hwif = "pf0",
        },
        {
          node = "worker-0",
          hwif = "pf0",
        }
      ]
      dev = {
        # Chipset SATA
        chipset-sata = {
          domain   = "0x0000"
          bus      = "0x00"
          slot     = "0x17"
          function = "0x0"
        }
        # HBA addon card
        hba = {
          domain   = "0x0000"
          bus      = "0x02"
          slot     = "0x00"
          function = "0x0"
          rom      = "/etc/libvirt/boot/SAS9300_8i_IT.bin"
        }
      }
    }
    kvm-1 = {
      hwif = [
        {
          label  = "pf0"
          if     = "en-pf0"
          mac    = "00-1b-21-bc-67-c6"
          numvfs = 15
        },
      ]
      network = [
        {
          label = "main"
          if    = "en-main"
          ip    = "192.168.127.252"
          dhcp  = true
          hwif  = "pf0"
        }
      ]
      metadata = {
        label = "int"
        if    = "en-int"
        ip    = local.services.renderer.vip
      }
      ## hypervisor boot image is copied with coreos-installer to strip
      ## out ignition and re-used to boot VMs
      libvirt_domains = [
        {
          node = "gateway-1",
          hwif = "pf0",
        },
        {
          node = "controller-1",
          hwif = "pf0",
        },
        {
          node = "controller-2",
          hwif = "pf0",
        },
        {
          node = "worker-1",
          hwif = "pf0",
        },
        {
          node = "test-0",
          hwif = "pf0",
        }
      ]
      dev = {
        # Chipset SATA
        chipset-sata = {
          domain   = "0x0000"
          bus      = "0x00"
          slot     = "0x17"
          function = "0x0"
        }
        # HBA addon card
        hba = {
          domain   = "0x0000"
          bus      = "0x02"
          slot     = "0x00"
          function = "0x0"
          rom      = "/etc/libvirt/boot/SAS9300_8i_IT.bin"
        }
      }
    }

    # client devices
    client-0 = {
      hwif = [
        {
          label  = "pf0"
          if     = "enp4s0f0"
          mac    = "f8-f2-1e-1e-3c-40"
          numvfs = 15
        }
      ]
      network = [
        {
          label = "main"
          if    = "en-main"
          ip    = "192.168.127.253"
          hwif  = "pf0"
        },
        {
          label = "lan"
          if    = "en-lan"
          dhcp  = true
          hwif  = "pf0"
        },
        {
          label    = "wan"
          if       = "en-wan"
          dhcp     = true
          hwif     = "pf0"
          disabled = true
        }
      ]
      disk = [
        {
          device     = "/dev/disk/by-label/localhome"
          mount_path = "/var/home/${local.client_user}"
        }
      ]
    }

    # unmanaged hardware
    switch-0 = {
      network = [
        {
          label = "main"
          ip    = "192.168.127.60"
          mac   = "50-c7-bf-60-78-22"
        }
      ]
    }
    ipmi-0 = {
      network = [
        {
          label = "main"
          ip    = "192.168.127.62"
          mac   = "ac-1f-6b-86-06-82"
        }
      ]
    }
    ipmi-1 = {
      network = [
        {
          label = "main"
          ip    = "192.168.127.61"
          mac   = "ac-1f-6b-ae-76-60"
        }
      ]
    }
  }

  # similar to guests filter
  # control which configs are rendered on local matchbox
  local_renderer_hosts_include = [
    "kvm-0",
    "kvm-1",
    "client-0",
  ]
}
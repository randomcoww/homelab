locals {
  timezone       = "America/Los_Angeles"
  butane_version = "1.5.0"
  default_mtu    = 9000

  users = {
    ssh = {
      name     = "fcos"
      home_dir = "/var/home/fcos"
      groups = [
        "adm",
        "sudo",
        "systemd-journal",
        "wheel",
      ],
    }
  }

  base_networks = {
    # Client access
    lan = {
      network        = "192.168.192.0"
      cidr           = 24
      vlan_id        = 2048
      mtu            = local.default_mtu
      enable_dns     = true
      enable_mdns    = true
      table_id       = 220
      table_priority = 32760
      netnums = {
        gateway = 2
        glkvm   = 126
        switch  = 127
      }
    }
    # BGP
    node = {
      network = "192.168.200.0"
      cidr    = 24
      vlan_id = 60
      mtu     = local.default_mtu
    }
    # Kubernetes service external IP and LB
    service = {
      network = "192.168.208.0"
      cidr    = 24
      vlan_id = 80
      mtu     = local.default_mtu
      netnums = {
        apiserver    = 2
        external_dns = 31
        matchbox     = 32
        matchbox_api = 33
        minio        = 34
        registry     = 35
      }
    }
    # Conntrack sync
    sync = {
      network        = "192.168.224.0"
      cidr           = 26
      vlan_id        = 90
      mtu            = local.default_mtu
      table_id       = 221
      table_priority = 32760
    }
    # Etcd peering
    etcd = {
      network = "192.168.228.0"
      cidr    = 26
      vlan_id = 70
      mtu     = local.default_mtu
    }
    # Primary WAN
    wan = {
      vlan_id = 30
    }
    # Backup WAN
    backup = {
      vlan_id = 1024
    }
    # Cluster internal
    kubernetes_service = {
      network = "10.96.0.0"
      cidr    = 12
      netnums = {
        cluster_apiserver     = 1
        cluster_dns           = 10
        cluster_kea_primary   = 12
        cluster_kea_secondary = 13
        cluster_minio         = 14
      }
    }
    kubernetes_pod = {
      network = "10.244.0.0"
      cidr    = 16
    }
  }

  fw_marks = {
    accept = "0x00002000"
  }

  # these fields are updated by renovate - don't use var substitutions
  container_images = {
    # static pod
    kube_apiserver          = "ghcr.io/randomcoww/kubernetes-control-plane:v1.34.1"
    kube_controller_manager = "ghcr.io/randomcoww/kubernetes-control-plane:v1.34.1"
    kube_scheduler          = "ghcr.io/randomcoww/kubernetes-control-plane:v1.34.1"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.4.3"
    etcd                    = "gcr.io/etcd-development/etcd:v3.6.5"
    # tier 1
    kube_proxy         = "ghcr.io/randomcoww/kubernetes-kube-proxy:v1.34.1.20250921.0744"
    kapprover          = "ghcr.io/randomcoww/kapprover:v0.1.0"
    flannel            = "docker.io/flannel/flannel:v0.27.3"
    flannel_cni_plugin = "docker.io/flannel/flannel-cni-plugin:v1.7.1-flannel1"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.0.0"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.19.0"
    # tier 2
    kea         = "ghcr.io/randomcoww/kea:v3.1.0.20250901.2312"
    stork_agent = "ghcr.io/randomcoww/stork-agent:v2.3.0.20250911.0103"
    ipxe        = "ghcr.io/randomcoww/ipxe:v20250921.0654"
    mountpoint  = "ghcr.io/randomcoww/mountpoint-s3:v1.20.0.20250921.0429"
    matchbox    = "quay.io/poseidon/matchbox:v0.11.0"
    nginx       = "docker.io/nginxinc/nginx-unprivileged:1.29.1-alpine"
    # tier 3
    hostapd               = "registry.default/randomcoww/hostapd-noscan:v2.11.20250918.1928"
    tailscale             = "registry.default/randomcoww/tailscale-nft:v1.88.2.20250918.1947"
    qrcode_generator      = "registry.default/randomcoww/qrcode-generator:v0.1.2"
    device_plugin         = "ghcr.io/squat/generic-device-plugin:latest"
    rclone                = "docker.io/rclone/rclone:1.71.0"
    audioserve            = "docker.io/izderadicka/audioserve:unstable"
    llama_cpp             = "ghcr.io/mostlygeek/llama-swap:v160-cuda-b6527"
    sunshine_desktop      = "registry.default/randomcoww/sunshine-desktop:v20250917.0509"
    litestream            = "docker.io/litestream/litestream:0.3.13"
    vaultwarden           = "docker.io/vaultwarden/server:1.34.3-alpine"
    juicefs               = "registry.default/randomcoww/juicefs:v1.3.0.20250921.0410"
    code_server           = "registry.default/randomcoww/code-server:v1.103.1.20250920.2248"
    flowise               = "docker.io/flowiseai/flowise:3.0.7"
    searxng               = "docker.io/searxng/searxng:2025.9.20-57ef342"
    valkey                = "docker.io/valkey/valkey:8.1.3-alpine"
    nvidia_driver         = "registry.default/randomcoww/nvidia-driver-container:v580.82.09.20250921.0120-fedora42"
    github_actions_runner = "ghcr.io/actions/actions-runner:2.328.0"
    registry              = "ghcr.io/distribution/distribution:3.0.0"
  }

  # these fields are updated by renovate - don't use var substitutions
  pxeboot_images = {
    coreos = "fedora-coreos-42.20250918.17" # randomcoww/fedora-coreos-config
  }

  host_ports = {
    kea_peer           = 50060
    kea_metrics        = 58087
    kea_ctrl_agent     = 58088
    ipxe_tftp          = 69 # required
    ipxe               = 58090
    apiserver          = 58181
    apiserver_backend  = 58081
    controller_manager = 50252
    scheduler          = 50251
    kubelet            = 50250
    kube_proxy         = 50254
    etcd_client        = 58082
    etcd_peer          = 58083
    etcd_metrics       = 58086
    flannel_healthz    = 58084
    bgp                = 179 # required
    kube_vip_metrics   = 58089
  }

  service_ports = {
    matchbox            = 443
    matchbox_api        = 50101
    minio               = 9000
    metrics             = 9153
    prometheus          = 80
    prometheus_blackbox = 9115
    llama_cpp           = 80
    searxng             = 8080
    registry            = 443 # required
  }

  ha = {
    keepalived_config_path = "/etc/keepalived/keepalived.conf.d"
    haproxy_config_path    = "/etc/haproxy/haproxy.cfg.d"
    bird_config_path       = "/etc/bird.conf.d"
    bird_cache_table_name  = "cache"
    bgp_as                 = 65005
  }

  domains = {
    mdns       = "local"
    public     = "fuzzybunny.win"
    kubernetes = "cluster.internal"
    tailscale  = "fawn-turtle.ts.net"
  }

  upstream_dns = {
    ip       = "1.1.1.1"
    hostname = "one.one.one.one"
  }

  kubernetes = {
    cluster_name              = "prod-10"
    kubelet_root_path         = "/var/lib/kubelet"
    static_pod_manifest_path  = "/var/lib/kubelet/manifests"
    containers_path           = "/var/lib/containers"
    cni_bin_path              = "/var/lib/cni/bin"
    cni_bridge_interface_name = "cni0"

    cert_issuer_prod    = "letsencrypt-prod"
    cert_issuer_staging = "letsencrypt-staging"

    kubelet_client_user     = "kube-apiserver-kubelet-client"
    front_proxy_client_user = "front-proxy-client"
    node_bootstrap_user     = "system:node-bootstrapper"

    ingress_classes = {
      ingress_nginx          = "ingress-nginx"
      ingress_nginx_external = "ingress-nginx-external"
    }
  }

  minio = {
    data_buckets = {
      boot = {
        name = "data-boot"
        acl  = "public-read"
      }
      music = {
        name = "data-music"
      }
      pictures = {
        name = "data-pictures"
      }
      videos = {
        name = "data-videos"
      }
      models = {
        name = "data-models"
      }
    }
  }

  kubernetes_services = {
    for name, e in merge({
      for k, class in local.kubernetes.ingress_classes :
      k => {
        name      = "${class}-controller"
        namespace = "ingress-nginx"
      }
      }, {
      apiserver = {
        name      = "kubernetes"
        namespace = "default"
      }
      etcd = {
        name      = "etcd"
        namespace = "kube-system"
      }
      kube_dns = {
        name      = "kube-dns"
        namespace = "kube-system"
      }
      matchbox = {
        name      = "matchbox"
        namespace = "default"
      }
      minio = {
        name      = "minio"
        namespace = "minio"
      }
      prometheus = {
        name      = "prometheus"
        namespace = "monitoring"
      }
      prometheus_blackbox = {
        name      = "prometheus-blackbox"
        namespace = "monitoring"
      }
      llama_cpp = {
        name      = "llama-cpp"
        namespace = "default"
      }
      searxng = {
        name      = "searxng"
        namespace = "default"
      }
      registry = {
        name      = "registry"
        namespace = "default"
      }
    }) :
    name => merge(e, {
      endpoint = "${e.name}.${e.namespace}"
    })
  }

  ingress_endpoints = {
    for k, domain in {
      qrcode_hostapd  = "hostapd"
      webdav_pictures = "pictures"
      webdav_videos   = "videos"
      sunshine_admin  = "sunadmin"
      audioserve      = "audioserve"
      vaultwarden     = "vw"
      flowise         = "flowise"
      llama_cpp       = "llm"
      code_server     = "code"
    } :
    k => "${domain}.${local.domains.public}"
  }

  # finalized local vars #

  networks = merge(local.base_networks, {
    for network_name, network in local.base_networks :
    network_name => merge(network, try({
      name   = network_name
      prefix = "${network.network}/${network.cidr}"
    }, {}))
  })

  services = merge([
    for network_name, network in local.networks :
    try({
      for service, netnum in network.netnums :
      service => {
        ip      = cidrhost(network.prefix, netnum)
        network = local.networks[network_name]
      }
    }, {})
    ]...
  )

  pxeboot_image_set = {
    for type, tag in local.pxeboot_images :
    type => {
      kernel = "${tag}-live-kernel.$${buildarch}"
      initrd = "${tag}-live-initramfs.$${buildarch}.img"
      rootfs = "${tag}-live-rootfs.$${buildarch}.img"
    }
  }
}

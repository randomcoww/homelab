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
      network     = "192.168.200.0"
      cidr        = 24
      vlan_id     = 60
      mtu         = local.default_mtu
      enable_mdns = true
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
    kube_apiserver          = "ghcr.io/randomcoww/kubernetes-control-plane:v1.34.1@sha256:9dd039d5c2456728d504e813958a0cd764d0a6784f7b54c13ec3ad555a1cc804"
    kube_controller_manager = "ghcr.io/randomcoww/kubernetes-control-plane:v1.34.1@sha256:9dd039d5c2456728d504e813958a0cd764d0a6784f7b54c13ec3ad555a1cc804"
    kube_scheduler          = "ghcr.io/randomcoww/kubernetes-control-plane:v1.34.1@sha256:9dd039d5c2456728d504e813958a0cd764d0a6784f7b54c13ec3ad555a1cc804"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.4.8@sha256:41ff93b85c5ae1aeca9af49fdfad54df02ecd4604331f6763a31bdaf73501464"
    etcd                    = "gcr.io/etcd-development/etcd:v3.6.5@sha256:042ef9c02799eb9303abf1aa99b09f09d94b8ee3ba0c2dd3f42dc4e1d3dce534"
    # tier 1
    kube_proxy         = "ghcr.io/randomcoww/kube-proxy:v1.34.1.20250928.0029@sha256:288388c5ff11a8fcf5d3327cc42b868ba30df25686cf794a67cbd02f0a61d12d"
    kapprover          = "ghcr.io/randomcoww/kapprover:v0.1.2@sha256:b51c36ff5000e62eaee29406822c61aa01a1b008f3874c0f5d468803cd1bee7e"
    flannel            = "ghcr.io/flannel-io/flannel:v0.27.3@sha256:8cc0cf9e94df48e98be84bce3e61984bbd46c3c44ad35707ec7ef40e96b009d1"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:latest@sha256:fa4749909ed22921a6710496f6462ca300848222c084327fb2e83133e14378e1"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.0.0@sha256:4f256554a83a6d824ea9c5307450a2c3fd132e09c52b339326f94fefaf67155c"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.19.0@sha256:f76114338104264f655b23138444481b20bb9d6125742c7240fac25936fe164e"
    # tier 2
    kea         = "ghcr.io/randomcoww/kea:v3.1.0.20250928.0049@sha256:29d6b6fbb0623c424edbc0d856e8f4dc015908c2eb90e6fa0b7da8c971db314c"
    stork_agent = "ghcr.io/randomcoww/stork-agent:v2.3.0.20250928.0049@sha256:e7e0b5b5123f56210ce7f99dfbde4b199faf9c02f15fb2b9c4e5720353c8819c"
    ipxe        = "ghcr.io/randomcoww/ipxe:v1.20250926.2052@sha256:19b3fed2fbfb33b6e22771f7b4ffa7b19e5a629e54d8466fba2e92f43d610adb"
    mountpoint  = "ghcr.io/randomcoww/mountpoint-s3:v1.20.0.20250928.0050@sha256:77a262fb1c116eff09f5c420e8648ed6213224a2f4ded5bdd36fa93eab974199"
    matchbox    = "quay.io/poseidon/matchbox:v0.11.0@sha256:06bcdae85335fd00e8277b007b55cfb49d96a0114628c0f70db2b92b079d246a"
    nginx       = "docker.io/nginxinc/nginx-unprivileged:1.29.1-alpine@sha256:9fda08cc7f7580567e9d8c477420d7beadb9387d4004074c89f41f9d90ecf300"
    # tier 3
    hostapd               = "registry.default/randomcoww/hostapd-noscan:v2.11.20250926.2051@sha256:f1b87bacef07ab2231f073f582eab32d9fb6b508b905bd5e86a981b06127c90f"
    tailscale             = "registry.default/randomcoww/tailscale-nft:v1.88.2.20250928.0031@sha256:41fa384c0b7efb80e18211c7d7751272beb147ecfe978d29eae570faaf5ebead"
    qrcode_generator      = "registry.default/randomcoww/qrcode-resource:v1.20250926.2053@sha256:9c63bb0f788a0c1ff855fa6cc9cd961faf7ddd982a541eeb32f8bbb58701ed71"
    device_plugin         = "ghcr.io/squat/generic-device-plugin:latest@sha256:359bcdd5c7b45a815a50e2f69c5942d85de6db03ff4a3923462af06161bead08"
    rclone                = "ghcr.io/rclone/rclone:1.71.1@sha256:d5971950c2b370fb04dd3292541b5bda6d9103143fd7e345aeb435a399388afc"
    audioserve            = "docker.io/izderadicka/audioserve:latest@sha256:c3609321701765671cae121fc0f61db122e8c124643c04770fbc9326c74b18e3"
    llama_cpp             = "ghcr.io/mostlygeek/llama-swap:cuda@sha256:32bc3dae662201040b08f2a24f5f91cf94f7b34d9bf334e090b3a85205fddf95"
    sunshine_desktop      = "registry.default/randomcoww/sunshine-desktop:v2025.927.211945.20250928.0101@sha256:86d74394415d5976d2bec6479ed6eb420c434fa13bbbb0e7115fd7fc4e96d759"
    litestream            = "docker.io/litestream/litestream:0.3.13@sha256:027eda2a89a86015b9797d2129d4dd447e8953097b4190e1d5a30b73e76d8d58"
    vaultwarden           = "ghcr.io/dani-garcia/vaultwarden:1.34.3-alpine@sha256:d70118b9dafb8588ee2651ceb5df68db27dcbd8e18467722010644ba48d5d6d6"
    juicefs               = "registry.default/randomcoww/juicefs:v1.3.0.20250928.0036@sha256:a7e5b85c3b14d8f35ef5e31f6c743f028c70a324ab75dc38941d6ef7b7c7ecc7"
    code_server           = "registry.default/randomcoww/code-server:v1.103.1.20250928.0029@sha256:ec6cede4d28990ce86f75fb9420961c99738851f486069a3cde20c50ccfd6f68"
    flowise               = "docker.io/flowiseai/flowise:3.0.7@sha256:11284f6a28c32d83df10f9382e66c576d9e73715d7ab8c416554dfd9af4e7570"
    searxng               = "ghcr.io/searxng/searxng:latest@sha256:b8a28fdff4a1d7697705a5931407f10240f98553b90468793c993ae5e21d1c32"
    valkey                = "ghcr.io/valkey-io/valkey:8.1.3-alpine@sha256:d827e7f7552cdee40cc7482dbae9da020f42bc47669af6f71182a4ef76a22773"
    nvidia_driver         = "registry.default/randomcoww/nvidia-driver-container:v580.82.09.20250923.2257-fedora42@sha256:d4ef9abc2aae670708e47f3dc98e6f8c88b6db3b1a70592afcb4328e6c447e05"
    github_actions_runner = "ghcr.io/actions/actions-runner:2.328.0@sha256:db0dcae6d28559e54277755a33aba7d0665f255b3bd2a66cdc5e132712f155e0"
    registry              = "ghcr.io/distribution/distribution:3.0.0@sha256:4ba3adf47f5c866e9a29288c758c5328ef03396cb8f5f6454463655fa8bc83e2"
    registry_ui           = "docker.io/quiq/registry-ui:0.10.4@sha256:88e90f14a2654b48a6ca8112b3bd000d3e2472a8cbf560d73af679f5558273f2"
  }

  # these fields are updated by renovate - don't use var substitutions
  pxeboot_images = {
    coreos = "fedora-coreos-42.20250925.16" # randomcoww/fedora-coreos-config
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
      monitoring      = "m"
      vaultwarden     = "vw"
      flowise         = "flowise"
      llama_cpp       = "llm"
      code_server     = "code"
      registry_ui     = "reg"
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

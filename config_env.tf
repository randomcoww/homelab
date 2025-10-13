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
        minio        = 34
        registry     = 35 # used by hosts without access to cluster DNS
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
      vlan_id     = 30
      enable_dhcp = true
    }
    # Backup WAN
    backup = {
      vlan_id     = 1024
      enable_dhcp = true
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

  container_image_regex = "(?<depName>(?<repository>[a-z0-9.-]+(?::\\d+|)(?:/[a-z0-9-]+|)+)/(?<image>[a-z0-9-]+)):(?<tag>(?<currentValue>(?<version>[\\w.]+)(?:-(?<compat>[\\w.-]+))?)(?:@(?<currentDigest>sha256:[a-f0-9]+))?)" # compatible with renovate

  # these fields are updated by renovate - don't use var substitutions
  container_images = {
    # static pod
    kube_apiserver          = "ghcr.io/randomcoww/kubernetes-control-plane:v1.34.1@sha256:9dd039d5c2456728d504e813958a0cd764d0a6784f7b54c13ec3ad555a1cc804"
    kube_controller_manager = "ghcr.io/randomcoww/kubernetes-control-plane:v1.34.1@sha256:9dd039d5c2456728d504e813958a0cd764d0a6784f7b54c13ec3ad555a1cc804"
    kube_scheduler          = "ghcr.io/randomcoww/kubernetes-control-plane:v1.34.1@sha256:9dd039d5c2456728d504e813958a0cd764d0a6784f7b54c13ec3ad555a1cc804"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.4.8@sha256:41ff93b85c5ae1aeca9af49fdfad54df02ecd4604331f6763a31bdaf73501464"
    etcd                    = "gcr.io/etcd-development/etcd:v3.6.5@sha256:042ef9c02799eb9303abf1aa99b09f09d94b8ee3ba0c2dd3f42dc4e1d3dce534"
    # tier 1
    kube_proxy         = "ghcr.io/randomcoww/kube-proxy:v1.34.1.20251013.1420@sha256:3bad8b9533f1928d1e2b7bdd537a14b26d6491ae346af9e978b16c9fe2482d2d"
    flannel            = "ghcr.io/flannel-io/flannel:v0.27.4@sha256:2ff3c5cb44d0e27b09f27816372084c98fa12486518ca95cb4a970f4a1a464c4"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:latest@sha256:25bd091c1867d0237432a4bcb5da720f39198b7d80edcae3bdf08262d242985c"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.0.1@sha256:554d1e07ee24a046bbc7fba67f438c01b480b072c6f0b99215321fc0eb440178"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.19.0@sha256:f76114338104264f655b23138444481b20bb9d6125742c7240fac25936fe164e"
    minio              = "quay.io/minio/minio:latest@sha256:14cea493d9a34af32f524e538b8346cf79f3321eff8e708c1e2960462bd8936e"
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.29.2-alpine@sha256:74b429937381f8e680ae527c8758c69f2a1b65373676aa97a2c7650c0e674cac"
    kea                = "ghcr.io/randomcoww/kea:v3.1.2.20251013.1409@sha256:c9b995702303cc24cdff1deedaecdc9367f70af43b754921e8c89b063f528852"
    stork_agent        = "ghcr.io/randomcoww/stork-agent:v2.3.0.20251013.1419@sha256:b26220c99a4c3d6de90e7d65c9b5b27c777f77a28c6b6dcd47454b8ac4fa6c3c"
    ipxe               = "ghcr.io/randomcoww/ipxe:v1.20251013.1418@sha256:fbb809b6d731b8a5a742e4437cb930e06ce8c7058df5f034e7ec1391d6f16d94"
    # tier 2
    mountpoint            = "ghcr.io/randomcoww/mountpoint-s3:v1.20.0.20251013.1427@sha256:1c7704319770ef730b78c015db86068c95e900cbd41990c4f9a1824b919f352b"
    hostapd               = "reg.cluster.internal/randomcoww/hostapd-noscan:v2.11.20251013.1424@sha256:3605ab6230dbcf49335b997e69c70a762478b0d972ce9e7c8effcce424be5fb3"
    tailscale             = "reg.cluster.internal/randomcoww/tailscale-nft:v1.88.3.20251013.1419@sha256:0221aa614b28e193c55021e6a13bcfe3f153d65fad0779c57de025d8895be9f0"
    qrcode_generator      = "reg.cluster.internal/randomcoww/qrcode-resource:v1.20250926.2053@sha256:9c63bb0f788a0c1ff855fa6cc9cd961faf7ddd982a541eeb32f8bbb58701ed71"
    device_plugin         = "ghcr.io/squat/generic-device-plugin:latest@sha256:dfed9c5fa93385719ef25eb5e88e5a06bd8748519b6a26ed2c9a2529d1c4f88c"
    rclone                = "ghcr.io/rclone/rclone:1.71.1@sha256:d5971950c2b370fb04dd3292541b5bda6d9103143fd7e345aeb435a399388afc"
    audioserve            = "docker.io/izderadicka/audioserve:latest@sha256:c3609321701765671cae121fc0f61db122e8c124643c04770fbc9326c74b18e3"
    llama_cpp             = "ghcr.io/mostlygeek/llama-swap:cuda@sha256:dc8c9ed293d5ce5eae74cd018812b974315a9d3b5d132c17a3271bc55243bb4b"
    sunshine_desktop      = "reg.cluster.internal/randomcoww/sunshine-desktop:v2025.1011.235710.20251013.1424@sha256:ca9d2f702bcfa012a80307926eadef4cf47f6253890a019720ab4f558d31db21"
    litestream            = "docker.io/litestream/litestream:0.5.0@sha256:74ed4af3e223f6ad6a81d0c7eb31a57de3d9bdffcc4765128a89e0f069fdb839"
    juicefs               = "reg.cluster.internal/randomcoww/juicefs:v1.3.0.20251013.1421@sha256:78d5369ab124f200bec263e29e3d6ec5bc4ae92974c80e34b8e04ccb0539f0bc"
    valkey                = "ghcr.io/valkey-io/valkey:8.1.4-alpine@sha256:e706d1213aaba6896c162bb6a3a9e1894e1a435f28f8f856d14fab2e10aa098b"
    nvidia_driver         = "reg.cluster.internal/randomcoww/nvidia-driver-container:v580.95.05.20251002.0720-fedora42@sha256:7cafab4ddef75b51aaa86e7209309680f0ad6bdbcd1fd943a6bb9573b2d46102"
    github_actions_runner = "ghcr.io/actions/actions-runner:2.328.0@sha256:db0dcae6d28559e54277755a33aba7d0665f255b3bd2a66cdc5e132712f155e0"
    registry              = "ghcr.io/distribution/distribution:3.0.0@sha256:4ba3adf47f5c866e9a29288c758c5328ef03396cb8f5f6454463655fa8bc83e2"
    registry_ui           = "docker.io/quiq/registry-ui:0.10.4@sha256:88e90f14a2654b48a6ca8112b3bd000d3e2472a8cbf560d73af679f5558273f2"
    mcp_proxy             = "ghcr.io/tbxark/mcp-proxy:v0.39.1@sha256:8e7a15c1375744ab9f5c42ebbee5aa694685af9ec43fe6da2ddf76ef96d765a5"
    searxng               = "ghcr.io/searxng/searxng:latest@sha256:d69b566421b494c0680adf2f78d757184abb2d3fd655a2f0e008b3b8d901bae7"
    open_webui            = "ghcr.io/open-webui/open-webui:0.6.33@sha256:133c51d50defc253251150a89dfbe6d55b797a630ac44a644394d01fc80b6225"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      coreos = "fedora-coreos-42.20251007.21" # renovate: randomcoww/fedora-coreos-config
    } :
    name => {
      kernel = "${tag}-live-kernel.$${buildarch:uristring}"
      initrd = "${tag}-live-initramfs.$${buildarch:uristring}.img"
      rootfs = "${tag}-live-rootfs.$${buildarch:uristring}.img"
    }
  }

  host_ports = {
    kea_peer           = 50060
    kea_metrics        = 58087
    kea_ctrl_agent     = 58088
    ipxe_tftp          = 69 # not configurable
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
    bgp                = 179 # not configurable
    kube_vip_metrics   = 58089
  }

  service_ports = {
    minio    = 9000
    metrics  = 9153
    registry = 443  # not configurable
    reloader = 9090 # not configurable
  }

  ha = {
    keepalived_config_path = "/etc/keepalived/keepalived.conf.d"
    haproxy_config_path    = "/etc/haproxy/haproxy.cfg.d"
    bird_config_path       = "/etc/bird.conf.d"
    bird_cache_table_name  = "cache"
    bgp_as                 = 65005
  }

  domains = {
    kubernetes = "cluster.internal"
    public     = "fuzzybunny.win"
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
    kubelet_client_user       = "kube-apiserver-kubelet-client"
    helm_release_timeout      = 600

    cert_issuers = {
      acme_prod    = "letsencrypt-prod"
      acme_staging = "letsencrypt-staging"
      ca_internal  = "internal"
    }
    ca_bundle_configmap = "ca-trust-bundle.crt"

    feature_gates = {
      ClusterTrustBundle           = true
      ClusterTrustBundleProjection = true
    }
  }

  endpoints = {
    for name, e in {
      ingress_nginx = {
        name      = "ingress-nginx"
        namespace = "ingress-nginx"
      }
      ingress_nginx_internal = {
        name      = "ingress-nginx-internal"
        namespace = "ingress-nginx"
      }
      apiserver = {
        name = "kubernetes"
      }
      etcd = {
        name      = "etcd"
        namespace = "kube-system"
      }
      kube_dns = {
        name      = "kube-dns"
        namespace = "kube-system"
      }
      kea = {
        name      = "kea"
        namespace = "netboot"
      }
      minio = {
        name      = "minio"
        namespace = "minio"
      }
      prometheus = {
        name      = "prometheus"
        namespace = "monitoring"
        ingress   = "prometheus.${local.domains.kubernetes}"
      }
      searxng = {
        name    = "searxng"
        ingress = "search.${local.domains.kubernetes}"
      }
      registry = {
        name    = "registry"
        service = "reg.${local.domains.kubernetes}"
        ingress = "reg.${local.domains.public}"
      }
      qrcode_hostapd = {
        name    = "qrcode-hostapd"
        ingress = "hostapd.${local.domains.public}"
      }
      webdav_pictures = {
        name    = "webdav-pictures"
        ingress = "pictures.${local.domains.public}"
      }
      audioserve = {
        name = "audioserve"
      }
      llama_cpp = {
        name    = "llama-cpp"
        ingress = "llama.${local.domains.kubernetes}"
      }
      sunshine_desktop = {
        name    = "sunshine-desktop"
        ingress = "sunadmin.${local.domains.public}"
      }
      mcp_proxy = {
        name    = "mcp-proxy"
        ingress = "mcp.${local.domains.kubernetes}"
      }
      open_webui = {
        name    = "open-webui"
        ingress = "chat.${local.domains.public}"
      }
    } :
    name => merge(e, {
      namespace = lookup(e, "namespace", "default")
      service   = "${lookup(e, "service", "${e.name}.${lookup(e, "namespace", "default")}")}"
      ingress   = "${lookup(e, "ingress", "${e.name}.${local.domains.public}")}"
    })
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
}
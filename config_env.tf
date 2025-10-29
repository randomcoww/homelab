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
    kube_apiserver          = "registry.k8s.io/kube-apiserver:v1.34.1@sha256:b9d7c117f8ac52bed4b13aeed973dc5198f9d93a926e6fe9e0b384f155baa902"
    kube_controller_manager = "registry.k8s.io/kube-controller-manager:v1.34.1@sha256:2bf47c1b01f51e8963bf2327390883c9fa4ed03ea1b284500a2cba17ce303e89"
    kube_scheduler          = "registry.k8s.io/kube-scheduler:v1.34.1@sha256:6e9fbc4e25a576483e6a233976353a66e4d77eb5d0530e9118e94b7d46fb3500"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.4.8@sha256:41ff93b85c5ae1aeca9af49fdfad54df02ecd4604331f6763a31bdaf73501464"
    etcd                    = "gcr.io/etcd-development/etcd:v3.6.5@sha256:042ef9c02799eb9303abf1aa99b09f09d94b8ee3ba0c2dd3f42dc4e1d3dce534"
    # tier 1
    kube_proxy         = "registry.k8s.io/kube-proxy:v1.34.1@sha256:913cc83ca0b5588a81d86ce8eedeb3ed1e9c1326e81852a1ea4f622b74ff749a"
    flannel            = "ghcr.io/flannel-io/flannel:v0.27.4@sha256:2ff3c5cb44d0e27b09f27816372084c98fa12486518ca95cb4a970f4a1a464c4"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:latest@sha256:20bcb9ad81033d9b22378f7834800437bc77ffa92509d78830d0008a29f430d5"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.0.1@sha256:554d1e07ee24a046bbc7fba67f438c01b480b072c6f0b99215321fc0eb440178"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.19.0@sha256:f76114338104264f655b23138444481b20bb9d6125742c7240fac25936fe164e"
    minio              = "ghcr.io/randomcoww/minio:RELEASE.2025-10-15T17-29-55Z.20251021.2244@sha256:21f046fd3848b8c2539c3aae29a3bd6921438c97a320955dafa41820169e7364"
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.29.2-alpine@sha256:dd1707e363384e88791da80a60d1566c0822731ef15ad8080a69bcbb2729c331"
    # tier 2
    kea                   = "ghcr.io/randomcoww/kea:v3.1.2.20251027.1410@sha256:84d1fea455d70fb3f31ac2cfff88eb8f96b3a254610af82096f0f441b42aab9b"
    stork_agent           = "ghcr.io/randomcoww/stork-agent:v2.3.1.20251027.1419@sha256:c6d9df6e394b8520861748776659ce4a5ce60c6059ceec8a51c6613f52f9d2d9"
    ipxe                  = "ghcr.io/randomcoww/ipxe:v1.20251027.1418@sha256:e7b7cc1859de9c291bee8d938ba311c2b01d62a3b8d5a6ec85c96f95101e8965"
    registry              = "ghcr.io/distribution/distribution:3.0.0@sha256:4ba3adf47f5c866e9a29288c758c5328ef03396cb8f5f6454463655fa8bc83e2"
    registry_ui           = "docker.io/quiq/registry-ui:0.10.4@sha256:88e90f14a2654b48a6ca8112b3bd000d3e2472a8cbf560d73af679f5558273f2"
    device_plugin         = "ghcr.io/squat/generic-device-plugin:latest@sha256:eebecd9172b4c2a61e4b3149c943a4ef2c293d7ceb89b69fec5ce5092eb7cf16"
    github_actions_runner = "ghcr.io/actions/actions-runner:2.329.0@sha256:75599cd393958a52142f489a160123f5b9b21605a40609696deb13d49867d53f"
    # tier 3
    mountpoint       = "reg.cluster.internal/randomcoww/mountpoint-s3:v1.20.0.20251027.1427@sha256:c150e2a3135d0594e8cac15b06c7610dc6bc6310e28ddcbc366f6abc8aa512e5"
    hostapd          = "reg.cluster.internal/randomcoww/hostapd-noscan:v1.20251027.1426@sha256:2f9213d49b7469dd1d915a4dd6b043bc18b2c5c58423206573631149d00bf7f1"
    tailscale        = "ghcr.io/tailscale/tailscale:v1.88.4@sha256:360e10ad95ad03950f66df03e0dab66287f9f89076ee4012d50bc6adceafcdf3"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v1.20251027.1418@sha256:1a44ee9e42cd16c3b0094dd9882be4a34702fb039c96de6bee173705c0db9258"
    llama_cpp        = "ghcr.io/mostlygeek/llama-swap:cuda@sha256:96e18c417778b08a8160e255484ffd8b5c4a3083a31462e1829cfc264e243bb6"
    sunshine_desktop = "reg.cluster.internal/randomcoww/sunshine-desktop:v2025.1026.25932.20251027.1425@sha256:68a04b45516d0fbd945e903e75038e2cd37715d974c087427cc16fb31ca65114"
    litestream       = "docker.io/litestream/litestream:0.5.2@sha256:e4fd484cb1cd9d6fa58fff7127d551118e150ab75b389cf868a053152ba6c9c0"
    valkey           = "ghcr.io/valkey-io/valkey:9.0.0-alpine@sha256:b4ee67d73e00393e712accc72cfd7003b87d0fcd63f0eba798b23251bfc9c394"
    nvidia_driver    = "reg.cluster.internal/randomcoww/nvidia-driver-container:v580.95.05.20251002.0720-fedora42@sha256:7cafab4ddef75b51aaa86e7209309680f0ad6bdbcd1fd943a6bb9573b2d46102"
    mcp_proxy        = "ghcr.io/tbxark/mcp-proxy:v0.42.0@sha256:fa322a8f68097ad182235865049ee3fa7d26bca7d2155156bdc1e179569a86bc"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:a943cb1111c2a61ef74162359de687cca94f5472d336e0a2dfef7be2259a4e8f"
    open_webui       = "ghcr.io/open-webui/open-webui:0.6.34@sha256:98d13c0a9285c110fba9814ef8bfbbaff9250863236fe3a18d29e93534289312"
    kavita           = "ghcr.io/kareadita/kavita:0.8.8@sha256:22c42f3cc83fb98b98a6d6336200b615faf2cfd2db22dab363136744efda1bb0"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      coreos = "fedora-coreos-42.20251024.19" # renovate: randomcoww/fedora-coreos-config-custom
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
      ImageVolume                  = true
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
      kavita = {
        name    = "kavita"
        ingress = "kavita.${local.domains.public}"
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
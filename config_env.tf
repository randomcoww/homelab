locals {
  timezone       = "America/Los_Angeles"
  butane_version = "1.5.0"
  default_mtu    = 1500 # TODO: move to 9000 - workaround for r8169 transmit queue timed out issue

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
      mtu            = 1500 # may bridge to wifi - fix to 1500
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

  # use same regex for renovate
  container_image_regex = "(?<depName>(?<repository>[a-z0-9.-]+(?::\\d+|)(?:/[a-z0-9-]+|)+)/(?<image>[a-z0-9.-]+)):(?<tag>(?<currentValue>(?<version>[\\w.]+)(?:-(?<compat>[\\w.-]+))?)(?:@(?<currentDigest>sha256:[a-f0-9]+))?)"

  # these fields are updated by renovate - don't use var substitutions
  container_images = {
    # static pod
    kube_apiserver          = "registry.k8s.io/kube-apiserver:v1.35.1@sha256:011838b85f65454b95a013b2b902dd506789fd07f9abc84e52eb2b6a044cd392"
    kube_controller_manager = "registry.k8s.io/kube-controller-manager:v1.35.1@sha256:9fb295baa9d68543d7bbecc23e16fcdf85c8c06680f91e628535aa6fbe180dbd"
    kube_scheduler          = "registry.k8s.io/kube-scheduler:v1.35.1@sha256:fc251ed4b8a03830bb8f75fb5fe983b3b0b5cc15a9c066d8f6c5d2e547deece8"
    etcd                    = "registry.k8s.io/etcd:v3.6.8@sha256:397189418d1a00e500c0605ad18d1baf3b541a1004d768448c367e48071622e5"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.5.27@sha256:b0a9926089e152490dfa215e6176a3fcc6deb72636b1c22cd16b2c0216509c4c"
    # tier 1
    kube_proxy         = "registry.k8s.io/kube-proxy:v1.35.1@sha256:a832f1cece7252b2e52294be5a59b7579ccde35202ad63e09e9f4f04c5676435"
    flannel            = "ghcr.io/flannel-io/flannel:v0.28.1@sha256:6a9c170acece4457ccb9cdfe53c787cc451e87990e20451bf20070b8895fa538"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:latest@sha256:c6a08fe5bcb23b19c2fc7c1e47b95a967cc924224ebedf94e8623f27b6c258fa"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.0.4@sha256:5e0d817bfa35f922e7ca5cf5fa88f30b71a88ab4837e550185b1c97bcef818c2"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.20.0@sha256:ddc7f4212ed09a21024deb1f470a05240837712e74e4b9f6d1f2632ff10672e7"
    minio              = "cgr.dev/chainguard/minio:latest@sha256:cff3b71951adab3a387ca7eba99c8a7e0e6d37b196cb821dc8bbce54569b1e68"
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.29.5-alpine@sha256:07ac04b4a727a38e7360f3bd8bbe49a7433a8e2a3259dd403d2c982e5f4c7a1c"
    # tier 2
    kea                   = "ghcr.io/randomcoww/kea:v3.1.5@sha256:6e6bf4a1e600a8f14c0fa3b50844f2d0a60551f412966c66d05534ac1255281e"
    ipxe                  = "ghcr.io/randomcoww/ipxe:v20260223.144318@sha256:29e3a5fcad5ff0263b5ad6101c8a96ee3d99d28f2ec3ccf67f2a6fa7ea1d284c"
    registry              = "ghcr.io/distribution/distribution:3.0.0@sha256:4ba3adf47f5c866e9a29288c758c5328ef03396cb8f5f6454463655fa8bc83e2"
    registry_ui           = "docker.io/quiq/registry-ui:0.12.0@sha256:0d066cddfb87427d1907801cd5f955a5af4633ac3bae25273184dd80a96289be"
    device_plugin         = "ghcr.io/squat/generic-device-plugin:latest@sha256:8e74085edef446b02116d0e851a7a5576b4681e07fe5be75c4e5f6791a8ad0f7"
    github_actions_runner = "ghcr.io/actions/actions-runner:2.331.0@sha256:dced476aa42703ebd9aafc295ce52f160989c4528e831fc3be2aef83a1b3f6da"
    # tier 3
    mountpoint       = "reg.cluster.internal/randomcoww/mountpoint-s3:v1.22.0@sha256:230736d1a7e68584b0173a06faeaf81d080de9a584e0038e346e2f286633b699"
    hostapd          = "reg.cluster.internal/randomcoww/hostapd-noscan:v20260223.145333@sha256:80eeb7ac451519af49d660146cf55dcfddf89cdf8b179160f9a338f8e291714d"
    tailscale        = "ghcr.io/tailscale/tailscale:v1.94.2@sha256:95e528798bebe75f39b10e74e7051cf51188ee615934f232ba7ad06a3390ffa1"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v20260223.144248@sha256:6612caed7fa7dbfc877e7d4c7bc1a204eb2a2420ea1207cb5ad1b0ab6b999479"
    llama_cpp_vulkan = "ghcr.io/ggml-org/llama.cpp:server-vulkan-b8140@sha256:21a1118c94b05e583957fff212d15ef102b84c10582143a56e2809c821e5739e"
    llama_cpp_rocm   = "reg.cluster.internal/randomcoww/llama-cpp-rocm:v8128-rocm7.2@sha256:21bf432993b597be04066ed28ea1c856257d26c6d1a035b883340cf0fa919259"
    llama_swap       = "ghcr.io/mostlygeek/llama-swap:vulkan-non-root@sha256:81bed9c2699b37afa20325a690d0bfa11d6c7e186f141daa1a6c6b742d396499"
    sunshine_desktop = "reg.cluster.internal/randomcoww/sunshine-desktop:v2026.206.151412@sha256:779d879975b00f88ed1351d4b0d81b70b0d2f83ac038a8e97634d19a00b1120f"
    litestream       = "docker.io/litestream/litestream:0.5.9@sha256:58e338ede90c193d5f880348170cd6d80164bbc35220906a3c360271e7317f71"
    valkey           = "ghcr.io/valkey-io/valkey:9.0.2-alpine@sha256:68677f85c863830af7836ff07c4a13b7f085ebeff62f4dedb71499ca27d229f2"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:edf110a2816d8963949d03879c72a7e19c221b5f7bfb7952a33ae073f96ccb18"
    open_webui       = "ghcr.io/open-webui/open-webui:v0.8.5@sha256:2deb90b0423473d8f97febced2e62b8fd898aa3eb61877bb3aa336370214c258"
    kavita           = "ghcr.io/kareadita/kavita:0.8.9@sha256:1f2acae7466d022f037ea09f7989eb7c487f916b881174c7a6de33dbfa8acb39"
    navidrome        = "ghcr.io/navidrome/navidrome:0.60.3@sha256:a5dce8f33304714dd138e870cca0dcab3d937ca236be1a9f2b97da009d1a0048"
    lldap            = "ghcr.io/lldap/lldap:latest-alpine@sha256:a14d2671e7c4fcc5557270c1ca1976777c7ab386c443c9703c573e63e56cf9a0"
    authelia         = "ghcr.io/authelia/authelia:4.39.15@sha256:d23ee3c721d465b4749cc58541cda4aebe5aa6f19d7b5ce0afebb44ebee69591"
    cloudflared      = "docker.io/cloudflare/cloudflared:2026.2.0@sha256:404528c1cd63c3eb882c257ae524919e4376115e6fe57befca8d603656a91a4c"
    mcp_proxy        = "ghcr.io/tbxark/mcp-proxy:v0.43.2@sha256:70c0e02d39c4c0898e610b3a30954f7930628fa6f4fb447bad14c32382a25879"
    prometheus_mcp   = "ghcr.io/pab1it0/prometheus-mcp-server:1.5.3@sha256:32d47c88845ee78bc343d4c3a39a24b1bd9bebce4f53becdbbf5704221185925"
    rclone           = "ghcr.io/rclone/rclone:1.73.1@sha256:c08f5e100e1c4fa4deb1315b56a47c0cc0e765222b7c0834bc93305f2e4d85c0"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      default = "fedora-coreos-43.20260217.09" # renovate: randomcoww/fedora-coreos-config-custom
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
    ipxe_tftp          = 69 # not configurable
    ipxe               = 58090
    apiserver          = 58181
    apiserver_backend  = 58081
    controller_manager = 50252
    scheduler          = 50251
    kubelet            = 50250
    kube_proxy         = 50254
    kube_proxy_metrics = 50255
    etcd_client        = 58082
    etcd_peer          = 58083
    etcd_metrics       = 58086
    flannel_healthz    = 58084
    bgp                = 179 # not configurable
    kube_vip_metrics   = 58089
    kube_vip_health    = 58088
  }

  service_ports = {
    minio    = 9000
    metrics  = 9153
    registry = 443 # not configurable
    ldaps    = 6360
  }

  ha = {
    keepalived_config_path = "/etc/keepalived/keepalived.conf.d"
    haproxy_config_path    = "/etc/haproxy/haproxy.cfg.d"
    bird_config_path       = "/etc/bird.conf.d"
    bird_cache_table_name  = "cache"
    bgp_as                 = 65005
  }

  domain_regex = "(?<subdomain>[a-z0-9-*]+)\\.(?<domain>[a-z0-9.-]+)"

  domains = {
    kubernetes = "cluster.internal"
    public     = "fuzzybunny.win"
  }

  upstream_dns = [
    {
      ip       = "1.1.1.1"
      hostname = "one.one.one.one"
    },
    {
      ip       = "1.0.0.1"
      hostname = "one.one.one.one"
    },
  ]

  kubernetes = {
    cluster_name              = "prod-10"
    kubelet_root_path         = "/var/lib/kubelet"
    static_pod_manifest_path  = "/var/lib/kubelet/manifests"
    containers_path           = "/var/lib/containers"
    cni_bin_path              = "/var/lib/cni/bin"
    cni_config_path           = "/etc/cni/net.d"
    cni_bridge_interface_name = "cni0"
    kubelet_client_user       = "kube-apiserver-kubelet-client"
    helm_release_timeout      = 600

    cert_issuers = {
      acme_prod    = "letsencrypt-prod"
      acme_staging = "letsencrypt-staging"
      ca_internal  = "internal"
    }
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
        service   = "ingress-nginx-controller.ingress-nginx" # Name created by helm chart
      }
      ingress_nginx_internal = {
        name      = "ingress-nginx-internal"
        namespace = "ingress-nginx"
        service   = "ingress-nginx-internal-controller.ingress-nginx" # Name created by helm chart
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
        ingress = "searxng.${local.domains.kubernetes}"
      }
      registry = {
        name    = "registry"
        service = "reg.${local.domains.kubernetes}"
        ingress = "reg-admin.${local.domains.kubernetes}"
      }
      qrcode_hostapd = {
        name    = "qrcode-hostapd"
        ingress = "hostapd.${local.domains.kubernetes}"
      }
      kavita = {
        name    = "kavita"
        ingress = "kavita.${local.domains.public}"
      }
      navidrome = {
        name    = "navidrome"
        ingress = "navidrome.${local.domains.public}"
      }
      llama_cpp = {
        name    = "llama-cpp"
        ingress = "llama-cpp.${local.domains.kubernetes}"
      }
      sunshine_desktop = {
        name    = "sunshine-desktop"
        service = "sunshine.${local.domains.kubernetes}"
        ingress = "sunshine-admin.${local.domains.kubernetes}"
      }
      open_webui = {
        name    = "open-webui"
        ingress = "owui.${local.domains.public}"
      }
      lldap = {
        name      = "lldap"
        namespace = "auth"
        ingress   = "ldap.${local.domains.kubernetes}"
      }
      authelia = {
        name      = "authelia"
        namespace = "auth"
        ingress   = "auth.${local.domains.public}"
      }
      prometheus_mcp = {
        name      = "prometheus-mcp"
        namespace = "monitoring"
        ingress   = "prometheus-mcp.${local.domains.kubernetes}"
      }
    } :
    name => merge(e, {
      namespace    = lookup(e, "namespace", "default")
      service      = "${lookup(e, "service", "${e.name}.${lookup(e, "namespace", "default")}")}"
      service_fqdn = "${e.name}.${lookup(e, "namespace", "default")}.svc.${local.domains.kubernetes}"
      ingress      = "${lookup(e, "ingress", "${e.name}.${local.domains.kubernetes}")}"
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
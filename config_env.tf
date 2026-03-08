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
    kube_apiserver          = "registry.k8s.io/kube-apiserver:v1.35.2@sha256:68cdc586f13b13edb7aa30a18155be530136a39cfd5ef8672aad8ccc98f0a7f7"
    kube_controller_manager = "registry.k8s.io/kube-controller-manager:v1.35.2@sha256:d9784320a41dd1b155c0ad8fdb5823d60c475870f3dd23865edde36b585748f2"
    kube_scheduler          = "registry.k8s.io/kube-scheduler:v1.35.2@sha256:5833e2c4b779215efe7a48126c067de199e86aa5a86518693adeef16db0ff943"
    etcd                    = "registry.k8s.io/etcd:v3.6.8@sha256:397189418d1a00e500c0605ad18d1baf3b541a1004d768448c367e48071622e5"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.5.27@sha256:b0a9926089e152490dfa215e6176a3fcc6deb72636b1c22cd16b2c0216509c4c"
    # tier 1
    kube_proxy         = "registry.k8s.io/kube-proxy:v1.35.2@sha256:015265214cc874b593a7adccdcfe4ac15d2b8e9ae89881bdcd5bcb99d42e1862"
    flannel            = "ghcr.io/flannel-io/flannel:v0.28.1@sha256:6a9c170acece4457ccb9cdfe53c787cc451e87990e20451bf20070b8895fa538"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:v1.9.0-flannel1@sha256:c6a08fe5bcb23b19c2fc7c1e47b95a967cc924224ebedf94e8623f27b6c258fa"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.0.4@sha256:5e0d817bfa35f922e7ca5cf5fa88f30b71a88ab4837e550185b1c97bcef818c2"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.20.0@sha256:ddc7f4212ed09a21024deb1f470a05240837712e74e4b9f6d1f2632ff10672e7"
    minio              = "cgr.dev/chainguard/minio:latest@sha256:c0d4aa0da9a55b539c3a43bd6e2ed9dab9a06ba1043c2966cfc04c820f658b52"
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.29.5-alpine@sha256:e93571f3d08325964770168617743bcce2d308255ded81e38172fb1803407e74"
    # tier 2
    kea                   = "ghcr.io/randomcoww/kea:v3.1.5@sha256:6e6bf4a1e600a8f14c0fa3b50844f2d0a60551f412966c66d05534ac1255281e"
    ipxe                  = "ghcr.io/randomcoww/ipxe:v2.0.0@sha256:f465e7da9a95e5456216e68d50ee4d6d32ac55e43462e589c3d607a26b47fcc3"
    registry              = "ghcr.io/distribution/distribution:3.0.0@sha256:4ba3adf47f5c866e9a29288c758c5328ef03396cb8f5f6454463655fa8bc83e2"
    registry_ui           = "docker.io/quiq/registry-ui:0.12.0@sha256:0d066cddfb87427d1907801cd5f955a5af4633ac3bae25273184dd80a96289be"
    device_plugin         = "ghcr.io/squat/generic-device-plugin:latest@sha256:78127620563730680371e2915d48d69dc3ab513f12c742ca6bcacd156051fd4b"
    github_actions_runner = "ghcr.io/actions/actions-runner:2.332.0@sha256:8c3f5970b8ceb90cbd3e89b80c6806bb74d9c31686e9177c743323a4539d12f5"
    # tier 3
    mountpoint       = "reg.cluster.internal/randomcoww/mountpoint-s3:v1.22.0@sha256:2f46945f64183d311c9e9d307439f6589606210d96092922f48897642b1d2bfe"
    hostapd          = "reg.cluster.internal/randomcoww/hostapd:v2.11@sha256:dbc6b2d09e2f4f2359697427dd605e5429c57b0438c393eba78c362196d9dbfb"
    tailscale        = "ghcr.io/tailscale/tailscale:v1.94.2@sha256:95e528798bebe75f39b10e74e7051cf51188ee615934f232ba7ad06a3390ffa1"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v20260302.144020@sha256:fc073ce81eb76944fdab1e51dd4478d14ac30148b93d24a4e4ec702fea835b7e"
    llama_cpp_vulkan = "ghcr.io/mostlygeek/llama-swap:vulkan-non-root@sha256:c7017eda34e9de6e9819b9c7b38e5d76018eef56f3d1e341fd9fd0d2af6a60d2"
    llama_cpp_rocm   = "ghcr.io/mostlygeek/llama-swap:rocm-non-root@sha256:c13b3496d6fe324b937053bdf6a7b0973d0ac534fb0a7f8cddc6d7dc71abd7fc"
    litestream       = "docker.io/litestream/litestream:0.5.9@sha256:58e338ede90c193d5f880348170cd6d80164bbc35220906a3c360271e7317f71"
    valkey           = "ghcr.io/valkey-io/valkey:9.0.3-alpine@sha256:ad4541b28b017bf4cd83ee057c51aafb21ea32e898e3f3b8b75e268650f2ac20"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:3e11c8454e62de8b5cbb5ba7f5b9568a6eb3d40414af1a884d435bf79b3bfe9f"
    open_webui       = "ghcr.io/open-webui/open-webui:v0.8.8@sha256:b478adc66210c1effe147d3e4a0d8845c0418b136ca14c314b9d83a087ad1c1f"
    kavita           = "ghcr.io/kareadita/kavita:0.8.9@sha256:1f2acae7466d022f037ea09f7989eb7c487f916b881174c7a6de33dbfa8acb39"
    lldap            = "ghcr.io/lldap/lldap:latest-alpine@sha256:af6daf88e67b2c6885d2426f711cb241751b515cc36a995d36ba77f2ffd199fb"
    authelia         = "ghcr.io/authelia/authelia:4.39.15@sha256:d23ee3c721d465b4749cc58541cda4aebe5aa6f19d7b5ce0afebb44ebee69591"
    cloudflared      = "docker.io/cloudflare/cloudflared:2026.2.0@sha256:404528c1cd63c3eb882c257ae524919e4376115e6fe57befca8d603656a91a4c"
    rclone           = "ghcr.io/rclone/rclone:1.73.2@sha256:8a17d9b5cd5ce71bbb42e49e92ee83575d7fb03f6233d949d328e9d029b9376d"
    sunshine_desktop = "reg.cluster.internal/randomcoww/sunshine-desktop:v2026.306.10834@sha256:392d2ea813e560d71a646ddca28496e0142380330db223594ff3a1c2bb7ac02c"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      default = "fedora-coreos-43.20260307.22" # renovate: randomcoww/fedora-coreos-config-custom
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
    crio_metrics       = 58091
  }

  service_ports = {
    minio    = 9000
    metrics  = 9100
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
      traefik = {
        name      = "traefik"
        namespace = "traefik"
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
      }
      searxng = {
        name = "searxng"
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
        name = "kavita"
      }
      llama_cpp = {
        name = "llama-cpp"
      }
      open_webui = {
        name    = "open-webui"
        ingress = "owui.${local.domains.public}"
      }
      lldap = {
        name      = "lldap"
        namespace = "auth"
        ingress   = "ldap.${local.domains.public}"
      }
      authelia = {
        name      = "authelia"
        namespace = "auth"
        ingress   = "auth.${local.domains.public}"
      }
      sunshine_desktop = {
        name    = "sunshine-desktop"
        service = "sunshine.${local.domains.kubernetes}"
        ingress = "sunshine.${local.domains.public}"
      }
    } :
    name => merge(e, {
      namespace    = lookup(e, "namespace", "default")
      service      = "${lookup(e, "service", "${e.name}.${lookup(e, "namespace", "default")}")}"
      service_fqdn = "${e.name}.${lookup(e, "namespace", "default")}.svc.${local.domains.kubernetes}"
      ingress      = "${lookup(e, "ingress", "${e.name}.${local.domains.public}")}"
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
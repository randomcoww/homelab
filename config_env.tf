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
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.29.2-alpine@sha256:2cddd18b805962549f850a5f6f1f4b3ccb667343e3c6ba42e8ce6a6f7e389709"
    # tier 2
    kea                   = "ghcr.io/randomcoww/kea:v3.1.3.20251103.1410@sha256:61f53321b7e86795aa92400b74a0f7f31d5abb008e48b07c8c5d1c0c9fc96522"
    stork_agent           = "ghcr.io/randomcoww/stork-agent:v2.3.1.20251103.1419@sha256:d80406fe8f3870078b7e37a266bc310b0ef423a28c647059788624be5e5142db"
    ipxe                  = "ghcr.io/randomcoww/ipxe:v1.20251103.1418@sha256:b83b470fb5d2a9d5734a3952bf9381b0cee8b0768958c3479cfbd37b102d0097"
    registry              = "ghcr.io/distribution/distribution:3.0.0@sha256:4ba3adf47f5c866e9a29288c758c5328ef03396cb8f5f6454463655fa8bc83e2"
    device_plugin         = "ghcr.io/squat/generic-device-plugin:latest@sha256:0cf725e91c3eb2ea095e8d825f290b9de5dc97110c82d0e92a76bf94618a8f50"
    github_actions_runner = "ghcr.io/actions/actions-runner:2.329.0@sha256:75599cd393958a52142f489a160123f5b9b21605a40609696deb13d49867d53f"
    # tier 3
    mountpoint       = "reg.cluster.internal/randomcoww/mountpoint-s3:v1.21.0.20251105.0520@sha256:814c54b4d51e364b332d615d08f7107fd27233a82a1b0b2856cc223461a5406f"
    hostapd          = "reg.cluster.internal/randomcoww/hostapd-noscan:v1.20251103.1425@sha256:a4133aa84c644cf2e62eb96448ec1f48715b4b2fe36407b7a617d614de0dcf45"
    tailscale        = "ghcr.io/tailscale/tailscale:v1.90.6@sha256:8eb8b450a85856807e8a216c4697333e15f8701cb6d344bed851bf6aa6a9605c"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v1.20251103.1417@sha256:ea9faabb3ece13c092455321c8f6cdbd15207a1580efbcf34f03bc2b748bd388"
    llama_cpp        = "ghcr.io/mostlygeek/llama-swap:cuda@sha256:64f47cbc4bc9bbeebc451756d26fe66420fe277b845e6f7c0c16fcab5fcce60b"
    sunshine_desktop = "reg.cluster.internal/randomcoww/sunshine-desktop:v2025.1027.181930.20251103.1424@sha256:ce75f850ccb7e30f092ebbcee614835e6ac295f9712eee1fdac54e635d55e699"
    litestream       = "docker.io/litestream/litestream:0.5.2@sha256:e4fd484cb1cd9d6fa58fff7127d551118e150ab75b389cf868a053152ba6c9c0"
    valkey           = "ghcr.io/valkey-io/valkey:9.0.0-alpine@sha256:b4ee67d73e00393e712accc72cfd7003b87d0fcd63f0eba798b23251bfc9c394"
    nvidia_driver    = "reg.cluster.internal/randomcoww/nvidia-driver-container:v580.105.08.20251105.1811-fedora43@sha256:45aa19ddd0fb4adb374bd2cbb49f1212177cbb22ff125729148b2a82bda849c5"
    mcp_proxy        = "ghcr.io/tbxark/mcp-proxy:v0.43.0@sha256:0ab33e72c494ee795e9b95922beab736f251514d9e6ec1dcbe6ca317749ba5d3"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:0bdb1336bc866df7682b88cc2372f576c5f7984a765f63467a89ed7a6fc57d29"
    open_webui       = "ghcr.io/open-webui/open-webui:0.6.34@sha256:98d13c0a9285c110fba9814ef8bfbbaff9250863236fe3a18d29e93534289312"
    kavita           = "ghcr.io/kareadita/kavita:0.8.8@sha256:22c42f3cc83fb98b98a6d6336200b615faf2cfd2db22dab363136744efda1bb0"
    lldap            = "ghcr.io/lldap/lldap:latest-alpine@sha256:59e99ffb8ca3634a907945ad33c50c328cc188618fe6a2a10a22703694d14313"
    authelia         = "ghcr.io/authelia/authelia:4.39.13@sha256:7adc2a95b6a4be9332f6a420fdf59c7031bff203d1046ab80d8fbd66f5b1095f"
    cloudflared      = "docker.io/cloudflare/cloudflared:2025.10.1@sha256:21f3607baf2384c54d592b0efe76dd5f548c0dbc083e62fa22c7fac3923d077f"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      coreos = "fedora-coreos-43.20251030.21" # renovate: randomcoww/fedora-coreos-config-custom
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
        ingress = "llama-cpp.${local.domains.kubernetes}"
      }
      sunshine_desktop = {
        name    = "sunshine-desktop"
        service = "sunshine.${local.domains.public}"
        ingress = "sunadmin.${local.domains.public}"
      }
      mcp_proxy = {
        name    = "mcp-proxy"
        ingress = "mcp-proxy.${local.domains.kubernetes}"
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
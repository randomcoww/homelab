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
    kube_apiserver          = "registry.k8s.io/kube-apiserver:v1.35.0@sha256:32f98b308862e1cf98c900927d84630fb86a836a480f02752a779eb85c1489f3"
    kube_controller_manager = "registry.k8s.io/kube-controller-manager:v1.35.0@sha256:3e343fd915d2e214b9a68c045b94017832927edb89aafa471324f8d05a191111"
    kube_scheduler          = "registry.k8s.io/kube-scheduler:v1.35.0@sha256:0ab622491a82532e01876d55e365c08c5bac01bcd5444a8ed58c1127ab47819f"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.5.11@sha256:43941534f5d3773a7c1e15bd78683dc19bb8f78287a4e4282d2d473c7c8cf738"
    etcd                    = "gcr.io/etcd-development/etcd:v3.6.7@sha256:70cd5d29d2efcbc4c15f2a63183fd537aae77ddbc46b3b97a8a97bc8751ec3b4"
    # tier 1
    kube_proxy         = "registry.k8s.io/kube-proxy:v1.35.0@sha256:c818ca1eff765e35348b77e484da915175cdf483f298e1f9885ed706fcbcb34c"
    flannel            = "ghcr.io/flannel-io/flannel:v0.27.4@sha256:2ff3c5cb44d0e27b09f27816372084c98fa12486518ca95cb4a970f4a1a464c4"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:latest@sha256:c6a08fe5bcb23b19c2fc7c1e47b95a967cc924224ebedf94e8623f27b6c258fa"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.0.3@sha256:4e2791cc0238ae01b3986d827f4d568a25d846c94bab51238fe6241281a27113"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.20.0@sha256:ddc7f4212ed09a21024deb1f470a05240837712e74e4b9f6d1f2632ff10672e7"
    minio              = "ghcr.io/randomcoww/minio:v20251015.172955@sha256:228bf7b720e6a477ebfba2fb206eb921157adf14b156a530d67de13cb403722a"
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.29.3-alpine@sha256:c3b9dd893f9ecd7046d3ac37b0dc218ff3c65fe53acd5cb5e1f97f3988272760"
    # tier 2
    kea                   = "ghcr.io/randomcoww/kea:v3.1.4@sha256:32dd7549d3f1b417714cba50c8d7fcb6eae5faf185f254d0c9750d3441fe01cc"
    stork_agent           = "ghcr.io/randomcoww/stork-agent:v2.3.2@sha256:a274284cc9ef93b4b3f4bb9d30d7698bda4709528e7a90d52f5dfc12e8613662"
    ipxe                  = "ghcr.io/randomcoww/ipxe:v20251222.141954@sha256:c8beb2c3dbbe2bd1abdf5f67278ad3d54e4da6ea18cfa867fb3c8892e00baf49"
    registry              = "ghcr.io/distribution/distribution:3.0.0@sha256:4ba3adf47f5c866e9a29288c758c5328ef03396cb8f5f6454463655fa8bc83e2"
    device_plugin         = "ghcr.io/squat/generic-device-plugin:latest@sha256:2b53d255017668d70d7f59ff0b874a66c3a50922d1f8cfff182e4c55b82251a1"
    github_actions_runner = "ghcr.io/actions/actions-runner:2.330.0@sha256:ee54ad8776606f29434f159196529b7b9c83c0cb9195c1ff5a7817e7e570dcfe"
    # tier 3
    mountpoint       = "reg.cluster.internal/randomcoww/mountpoint-s3:v1.21.0@sha256:a91494ef56b9ff1ea4273c54ee42590a251547dc2263813cef2e55a9cf31c3eb"
    hostapd          = "reg.cluster.internal/randomcoww/hostapd-noscan:v20251222.142650@sha256:6cbfc83210fb147167bb99c57af7484ebb4f1a0da6424f209314977ecaa84c8b"
    tailscale        = "ghcr.io/tailscale/tailscale:v1.92.4@sha256:d6734d69fd7d31b1861589e347463954aa6097f9a61aa4f8f763ba94bfe0e5b9"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v20251222.141851@sha256:f60755e6d2cdeb15b190a758b4b1f2371f15d0a143f3ad1ccf82aaa11c8ec268"
    llama_cpp        = "ghcr.io/mostlygeek/llama-swap:cuda@sha256:0c4e2f04fc3890d0c7db2cf6d0f8bba6991a37ea60f4514db590b8f9de25f95a"
    sunshine_desktop = "reg.cluster.internal/randomcoww/sunshine-desktop:v2025.1210.519@sha256:f44421bec95df3ddaea3d95bdeab200cf4a73d3c58c9eacc4ac0590dd7ca28e4"
    litestream       = "docker.io/litestream/litestream:0.5.5@sha256:bc24c1bc5a551dca0f235c446e5fa890eaf455723cd8b8b294e732f144f091e4"
    valkey           = "ghcr.io/valkey-io/valkey:9.0.1-alpine@sha256:c106a0c03bcb23cbdf9febe693114cb7800646b11ca8b303aee7409de005faa8"
    nvidia_driver    = "reg.cluster.internal/randomcoww/nvidia-driver-container:v580.105.08-fedora43@sha256:b84a1f8f2ae22727a66cdfe518279917fb1cf752474d89af7ca87992642a0fa4"
    mcp_proxy        = "ghcr.io/tbxark/mcp-proxy:v0.43.0@sha256:0ab33e72c494ee795e9b95922beab736f251514d9e6ec1dcbe6ca317749ba5d3"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:13de9d465bd2d9da6a6718f2a57d96e6e5fa3b8aba3c0bec077a5b7e5f24e4e9"
    open_webui       = "ghcr.io/open-webui/open-webui:0.6.43@sha256:9cb724e0bc84f05ba2f81a3da5f53f5add07e1001065d83f3b6b70b9a9eeef19"
    kavita           = "ghcr.io/kareadita/kavita:0.8.8@sha256:22c42f3cc83fb98b98a6d6336200b615faf2cfd2db22dab363136744efda1bb0"
    lldap            = "ghcr.io/lldap/lldap:latest-alpine@sha256:72f526a8df92e8457d44d9a625cfbe43273285776c979e7144a31b26ebe65d1a"
    authelia         = "ghcr.io/authelia/authelia:4.39.15@sha256:d23ee3c721d465b4749cc58541cda4aebe5aa6f19d7b5ce0afebb44ebee69591"
    cloudflared      = "docker.io/cloudflare/cloudflared:2025.11.1@sha256:89ee50efb1e9cb2ae30281a8a404fed95eb8f02f0a972617526f8c5b417acae2"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      coreos = "fedora-coreos-43.20251223.22" # renovate: randomcoww/fedora-coreos-config-custom
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
    cni_config_path           = "/etc/cni/net-custom.d" # crio package drops unwanted configs into /etc/cni/net.d - work around by using another path
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
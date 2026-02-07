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
    kube_apiserver          = "registry.k8s.io/kube-apiserver:v1.35.0@sha256:32f98b308862e1cf98c900927d84630fb86a836a480f02752a779eb85c1489f3"
    kube_controller_manager = "registry.k8s.io/kube-controller-manager:v1.35.0@sha256:3e343fd915d2e214b9a68c045b94017832927edb89aafa471324f8d05a191111"
    kube_scheduler          = "registry.k8s.io/kube-scheduler:v1.35.0@sha256:0ab622491a82532e01876d55e365c08c5bac01bcd5444a8ed58c1127ab47819f"
    etcd                    = "registry.k8s.io/etcd:v3.6.7@sha256:70cd5d29d2efcbc4c15f2a63183fd537aae77ddbc46b3b97a8a97bc8751ec3b4"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.5.22@sha256:df898340b4d8e57758d9b3aa82981bc09e2c7943456ecbb25adf0e97b3cdde64"
    # tier 1
    kube_proxy         = "registry.k8s.io/kube-proxy:v1.35.0@sha256:c818ca1eff765e35348b77e484da915175cdf483f298e1f9885ed706fcbcb34c"
    flannel            = "ghcr.io/flannel-io/flannel:v0.28.1@sha256:6a9c170acece4457ccb9cdfe53c787cc451e87990e20451bf20070b8895fa538"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:latest@sha256:c6a08fe5bcb23b19c2fc7c1e47b95a967cc924224ebedf94e8623f27b6c258fa"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.0.4@sha256:5e0d817bfa35f922e7ca5cf5fa88f30b71a88ab4837e550185b1c97bcef818c2"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.20.0@sha256:ddc7f4212ed09a21024deb1f470a05240837712e74e4b9f6d1f2632ff10672e7"
    minio              = "cgr.dev/chainguard/minio:latest@sha256:14832794cf7bd4d14dbbaf1ebb02934c6a9bc573da5646a25987d9b7894c4499"
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.29.5-alpine@sha256:a731ba0194833ae0f80994a4ae08988aa95fdcc88f4f991340ce160770cf2b6d"
    # tier 2
    kea                   = "ghcr.io/randomcoww/kea:v3.1.5@sha256:3ba43c235c694daaf010a511160e5515fe5e1b6109e261debf8d6467b4b346cf"
    ipxe                  = "ghcr.io/randomcoww/ipxe:v20260202.143916@sha256:6766f3d8487c6e15590679bfda039b8c183eb46189d406c0df493146d8358c96"
    registry              = "ghcr.io/distribution/distribution:3.0.0@sha256:4ba3adf47f5c866e9a29288c758c5328ef03396cb8f5f6454463655fa8bc83e2"
    registry_ui           = "docker.io/quiq/registry-ui:0.11.0@sha256:9dac46b82a0df53cf2a8090c34c7d9e3ac0f5134ddd73cd948e2e3f9bb02f38d"
    device_plugin         = "ghcr.io/squat/generic-device-plugin:latest@sha256:8e74085edef446b02116d0e851a7a5576b4681e07fe5be75c4e5f6791a8ad0f7"
    github_actions_runner = "ghcr.io/actions/actions-runner:2.331.0@sha256:dced476aa42703ebd9aafc295ce52f160989c4528e831fc3be2aef83a1b3f6da"
    # tier 3
    mountpoint       = "reg.cluster.internal/randomcoww/mountpoint-s3:v1.22.0@sha256:b1995275bd35801ff4307ee434a31bcb919916e5ff41d47e3eb656ebb4c7b858"
    hostapd          = "reg.cluster.internal/randomcoww/hostapd-noscan:v20260202.145255@sha256:a0f4d96af428173df5e3ce91529290a26c290cdd705aaa20b91830420a4893f9"
    tailscale        = "ghcr.io/tailscale/tailscale:v1.94.1@sha256:21df0b5a84efa35c0a507f4dd2340e1b1295683634a28968707354d5bd991d9c"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v20260202.143842@sha256:b11e7f8a6fe916cf8f72f42cc4e24576cadf689eb5860380ad3f609878be06d1"
    llama_cpp_vulkan = "ghcr.io/ggml-org/llama.cpp:server-vulkan-b7964@sha256:9471d5a05073e97afdb24940a54b5bfe1c1f52e1a9aa8f68f97a7d430dbceb87"
    llama_cpp_rocm   = "reg.cluster.internal/randomcoww/llama-cpp-rocm:v7935-rocm7.2@sha256:54b405c6aa47840bf3a7da3cdc25c3db94bf631dfdd5acb5946937ddc6977c3c"
    llama_swap       = "reg.cluster.internal/randomcoww/llama-swap:v189@sha256:1cde0a8aabaa8e70fa1496cba9cfafc5652fdabe4e74d44270c1b3f56f58f3fe"
    sunshine_desktop = "reg.cluster.internal/randomcoww/sunshine-desktop:v2026.131.140325@sha256:64de4312ddd13f56a3f1b9841b6ce8a634502bc987b48e3d296fab86be4f8f11"
    litestream       = "docker.io/litestream/litestream:0.5.7@sha256:c96c7f68b714c09f482e10502b838e4eee42470f686501ce89916af30e18f9ef"
    valkey           = "ghcr.io/valkey-io/valkey:9.0.2-alpine@sha256:68677f85c863830af7836ff07c4a13b7f085ebeff62f4dedb71499ca27d229f2"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:670bd1076097640fc25221bf92a8af7d344503ce17ba3305abedf28e3634e807"
    open_webui       = "ghcr.io/open-webui/open-webui:0.7.2@sha256:16d9a3615b45f14a0c89f7ad7a3bf151f923ed32c2e68f9204eb17d1ce40774b"
    kavita           = "ghcr.io/kareadita/kavita:0.8.9@sha256:1f2acae7466d022f037ea09f7989eb7c487f916b881174c7a6de33dbfa8acb39"
    navidrome        = "ghcr.io/navidrome/navidrome:0.60.0@sha256:5d0f6ab343397c043c7063db14ae10e4e3980e54ae7388031cbce47e84af6657"
    lldap            = "ghcr.io/lldap/lldap:latest-alpine@sha256:244097722edaf9aeb0154d83318ff812ceb488cb4be7092defacbb7435243a0a"
    authelia         = "ghcr.io/authelia/authelia:4.39.15@sha256:d23ee3c721d465b4749cc58541cda4aebe5aa6f19d7b5ce0afebb44ebee69591"
    cloudflared      = "docker.io/cloudflare/cloudflared:2026.2.0@sha256:404528c1cd63c3eb882c257ae524919e4376115e6fe57befca8d603656a91a4c"
    mcp_proxy        = "ghcr.io/tbxark/mcp-proxy:v0.43.2@sha256:70c0e02d39c4c0898e610b3a30954f7930628fa6f4fb447bad14c32382a25879"
    prometheus_mcp   = "ghcr.io/pab1it0/prometheus-mcp-server:1.5.3@sha256:32d47c88845ee78bc343d4c3a39a24b1bd9bebce4f53becdbbf5704221185925"
    rclone           = "ghcr.io/rclone/rclone:1.73.0@sha256:9f59fda717a48aced38d7f27e9ec8fd9992b5651e7a03897bebf204d3a9197d6"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      default = "fedora-coreos-43.20260203.09" # renovate: randomcoww/fedora-coreos-config-custom
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
        ingress = "hub.reg.${local.domains.kubernetes}"
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
        ingress = "llama-cpp.${local.domains.public}"
      }
      sunshine_desktop = {
        name    = "sunshine-desktop"
        service = "sunshine.${local.domains.kubernetes}"
        ingress = "admin.sunshine.${local.domains.kubernetes}"
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
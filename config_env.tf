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
      enable_netnum  = true
      netnums = {
        gateway = 2
        glkvm   = 126
        switch  = 127
      }
    }
    # BGP
    node = {
      network       = "192.168.200.0"
      cidr          = 24
      vlan_id       = 60
      mtu           = 1500
      enable_netnum = true
    }
    # Kubernetes service external IP and LB
    service = {
      network       = "192.168.208.0"
      cidr          = 24
      vlan_id       = 80
      mtu           = 1500
      enable_netnum = true
      netnums = {
        apiserver   = 2
        k8s_gateway = 31
        minio       = 34
        registry    = 35 # used by hosts without access to cluster DNS
        gateway_api = 36
      }
    }
    # Conntrack sync
    sync = {
      network        = "192.168.224.0"
      cidr           = 26
      vlan_id        = 90
      mtu            = 1500
      table_id       = 221
      table_priority = 32760
      enable_netnum  = true
    }
    # Etcd peering
    etcd = {
      network       = "192.168.228.0"
      cidr          = 26
      vlan_id       = 70
      mtu           = 1500
      enable_netnum = true
    }
    # Primary WAN
    wan = {
      vlan_id     = 30
      enable_dhcp = true
    }
    # Backup WAN
    backup = {
      vlan_id     = 1024
      metric      = 4096
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
    kube_apiserver          = "registry.k8s.io/kube-apiserver:v1.35.3@sha256:6c6e2571f98e738015a39ed21305ab4166a3e2873f9cc01d7fa58371cf0f5d30"
    kube_controller_manager = "registry.k8s.io/kube-controller-manager:v1.35.3@sha256:23a24aafa10831eb47477b0b31a525ee8a4a99d2c17251aac46c43be8201ec59"
    kube_scheduler          = "registry.k8s.io/kube-scheduler:v1.35.3@sha256:7070dff574916315268ab483f1088a107b1f3a8a1a87f3e3645933111ade7013"
    etcd                    = "registry.k8s.io/etcd:v3.6.10@sha256:f65c61039e7b7fd6e651f7ec2459b880589892cb13cf79c2f71c92aa08fc5144"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.5.31@sha256:b3349d42a116d7406bfde97b41f2fff80696e5ffc35ce5e6571b9b441901b386"
    # tier 1
    kube_proxy         = "registry.k8s.io/kube-proxy:v1.35.3@sha256:8743aec6a360aedcb7a076cbecea367b072abe1bfade2e2098650df502e2bc89"
    flannel            = "ghcr.io/flannel-io/flannel:v0.28.2@sha256:3726b7dd2f758f1cc8155edc442e7f3fbad68cf42530d6bcb3ddffdba40a1394"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:v1.9.0-flannel1@sha256:c6a08fe5bcb23b19c2fc7c1e47b95a967cc924224ebedf94e8623f27b6c258fa"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.1.2@sha256:840305b94ef2a89abb3b7fd2b09edfbde690d90052020da4dff90679fe892da2"
    minio              = "cgr.dev/chainguard/minio:latest@sha256:ecba9ddf8ac5d988e046f92f1eff99ccb2cb9d62d20a4300f99c31f8486eb31e"
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.29.8-alpine@sha256:72cd9a222d01fdf47bd47ad8dc50b0221a768742b84a66c5e0b94ed13bcc6c72"
    # tier 2
    kea           = "ghcr.io/randomcoww/kea:v3.1.7@sha256:7dee1db74d16386194ec650b7d2e593fd0d8449ab1684880a689bf30426ef30f"
    ipxe          = "ghcr.io/randomcoww/ipxe:v2.0.0@sha256:dc7c61de8f4f122026689184d9427f495d98901859f15d31920c7af5523f7732"
    registry      = "ghcr.io/distribution/distribution:3.1.0@sha256:4fdc7c11dd6b58fd06e386971bf29929eebd831a074197ad1457a1aefeacf3da"
    device_plugin = "ghcr.io/squat/generic-device-plugin:0.2.0@sha256:66c8d5c270eb2b721f1064c549b9b7898152a6d2f0163380a5d37dc7636c20ff"
    gha_runner    = "ghcr.io/actions/actions-runner:2.333.1@sha256:b57864c9fcda15ea4a270446aa9cfb108b819a26f6e71fc515f6caf6c27989c6"
    # tier 3
    mountpoint       = "reg.cluster.internal/randomcoww/mountpoint-s3:v1.22.2.1776093703@sha256:e41432252902855289d37fc691be210af944c66531c0ceb7a875bc1609dec355"
    hostapd          = "reg.cluster.internal/randomcoww/hostapd:v2.11.1776092802@sha256:4b1f182c1601bfece58d4a1ee5dbef2250ea1e9a7e6419cdbe3d507879487773"
    tailscale        = "ghcr.io/tailscale/tailscale:v1.96.5@sha256:dbeff02d2337344b351afac203427218c4d0a06c43fc10a865184063498472a6"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v1776093227@sha256:343e69e6b524578252cd0b8e60e7a7e7de05f0c17e109fd61544153112b3a52d"
    llama_cpp_vulkan = "ghcr.io/mostlygeek/llama-swap:vulkan@sha256:4498037cfecdbffeb09213247b5726b17a3cff60a2cd19e85bd2f943b0bb07d6"
    litestream       = "docker.io/litestream/litestream:0.5.11@sha256:79e3bfce6ed758722916f816b028fffd9e0a971058f41b88e2779510cead1d8d"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:4c6b4f3e1fc10a907a40b7eaaf5b92d50f5b4097d6fb5b02041c0f9926233b36"
    open_webui       = "ghcr.io/open-webui/open-webui:v0.8.12@sha256:8113fa5510020ef05a44afc0c42d33eabeeb2524a996e3e3fb8c437c00f0d792"
    lldap            = "ghcr.io/lldap/lldap:latest-alpine@sha256:af6daf88e67b2c6885d2426f711cb241751b515cc36a995d36ba77f2ffd199fb"
    authelia         = "ghcr.io/authelia/authelia:4.39.19@sha256:0c824dcab1ae97c56bf673c5e77fe8cc6bcd400564555140cc8002a12c6b6463"
    cloudflared      = "docker.io/cloudflare/cloudflared:2026.3.0@sha256:6b599ca3e974349ead3286d178da61d291961182ec3fe9c505e1dd02c8ac31b0"
    sunshine_desktop = "reg.cluster.internal/randomcoww/sunshine-desktop:v2026.412.25828.1776093272@sha256:b263ceaac52903b60cd48b6ffba106e7e51680c82e8b15d92941e0b01b5a5236"
    kubernetes_mcp   = "ghcr.io/containers/kubernetes-mcp-server:latest@sha256:f5d192da0405a29800ad15b4c46b6292c10d2fca764b81c6afe2f4d8fcdc06b5"
    prometheus_mcp   = "ghcr.io/pab1it0/prometheus-mcp-server:1.6.0@sha256:06259d8cc17469edd79989fd4b9de57cec7afb028e1469c02ebada6a952de5e1"
    navidrome        = "ghcr.io/navidrome/navidrome:0.61.2@sha256:9fa40b3d8dec43ceb2213d1fa551da3dcfef6ac6d19c2e534efb92527c2bafd2"
    valkey           = "ghcr.io/valkey-io/valkey:9.1-alpine@sha256:355ae2c6c965769a0d9b9810711e6befd5b79fe676d1faa848247733ad6a4408"
    thanos           = "quay.io/thanos/thanos:v0.41.0@sha256:cf3e9b292e4302ad4a4955b56379703aea39516607d382a57604a3d003c35d10"
    stump            = "docker.io/aaronleopold/stump:nightly@sha256:44e94d36808fac9fe72b57779d89ae3028b3d632ec5cb64f887d2d2fa7182070"

    # models (model_file)
    "v5-small-text-matching-Q8_0.gguf"                                = "reg.cluster.internal/randomcoww/jina-embeddings-v5-text-small-text-matching-q8-0:v1773615151@sha256:ead9710eb051ea3b6ee32cebc1d1a8ba782c9e589ea972b48b15c173e169c4ee"
    "jina-reranker-v3-Q8_0.gguf"                                      = "reg.cluster.internal/randomcoww/jina-reranker-v3-q8-0:v1773185353@sha256:f9f985cd629f0a3f39d07de317545bb733ca14148f31040d567d267a8364ab4f"
    "NVIDIA-Nemotron-3-Super-120B-A12B-MXFP4_MOE-00001-of-00003.gguf" = "reg.cluster.internal/randomcoww/nvidia-nemotron-3-super-120b-a12b-mxfp4-moe:v1773610375@sha256:7c5065d9e53b4752fd40b496cd287946f5f5e5308ad29bfdea81c0622de6da0f"
    "GLM-4.7-Flash-Q8_0.gguf"                                         = "reg.cluster.internal/randomcoww/glm-4.7-flash-q8-0:v1773627383@sha256:1b2e6d762b1c003cbf5a2b79ea3a15fd309d436fdcb9229d3819a39366cb8645"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      default = "43.20260405.20.1.1775862745" # renovate: datasource=github-tags depName=randomcoww/fedora-coreos-config-custom
    } :
    name => {
      kernel = "fedora-coreos-${tag}-live-kernel.$${buildarch:uristring}"
      initrd = "fedora-coreos-${tag}-live-initramfs.$${buildarch:uristring}.img"
      rootfs = "fedora-coreos-${tag}-live-rootfs.$${buildarch:uristring}.img"
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
    minio          = 9000
    metrics        = 9100
    registry       = 443 # not configurable
    ldaps          = 6360
    redis_sentinel = 26379
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
      acme_prod   = "letsencrypt-prod"
      ca_internal = "internal"
    }
    feature_gates = {
      ClusterTrustBundle           = true
      ClusterTrustBundleProjection = true
      NodeLogQuery                 = true
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
      k8s_gateway = {
        name      = "k8s-gateway"
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
      }
      qrcode_hostapd = {
        name    = "qrcode-hostapd"
        ingress = "hostapd.${local.domains.public}"
      }
      llama_cpp = {
        name = "llama-cpp"
      }
      open_webui = {
        name    = "open-webui"
        ingress = "owui.${local.domains.public}"
        tunnel  = true
      }
      lldap = {
        name      = "lldap"
        namespace = "auth"
        ingress   = "ldap.${local.domains.public}"
      }
      authelia_valkey = {
        name      = "authelia-valkey"
        namespace = "auth"
      }
      authelia = {
        name      = "authelia"
        namespace = "auth"
        ingress   = "auth.${local.domains.public}"
        tunnel    = true
      }
      sunshine_desktop = {
        name    = "sunshine-desktop"
        service = "sunshine.${local.domains.public}"
        ingress = "sunshine-admin.${local.domains.public}"
      }
      navidrome = {
        name   = "navidrome"
        tunnel = true
      }
      stump = {
        name   = "stump"
        tunnel = true
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

  container_images_digest = {
    for name, image in local.container_images :
    name => "${regex(local.container_image_regex, image).depName}@${regex(local.container_image_regex, image).currentDigest}"
  }
}
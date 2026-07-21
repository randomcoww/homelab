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
    kube_apiserver          = "registry.k8s.io/kube-apiserver:v1.36.2@sha256:0535dde1a857029209d7effe681c919a1580d2eb24eda4bd122d24e9a372e1b8"
    kube_controller_manager = "registry.k8s.io/kube-controller-manager:v1.36.2@sha256:b3add29a00c3c4763c75a09ec94915e3d0d590b93b3850a97d52970fbd2b2c12"
    kube_scheduler          = "registry.k8s.io/kube-scheduler:v1.36.2@sha256:94dfc9f285718a06bb873947959b8514ed95dddaa7c74d765cc346fdfa684859"
    etcd                    = "registry.k8s.io/etcd:v3.7.0@sha256:6ecefbe2510c4a30573a62a4d6dd175acf881ca67003fcd91849a16df7a724d5"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.5.31@sha256:b3349d42a116d7406bfde97b41f2fff80696e5ffc35ce5e6571b9b441901b386"
    # tier 1
    kube_proxy         = "registry.k8s.io/kube-proxy:v1.36.2@sha256:620a27c742eb5ebf5be8613b7458b7ce7cd31e2804b61b98f6516e328002c4cc"
    flannel            = "ghcr.io/flannel-io/flannel:v0.28.7@sha256:f90b69bc851107660de618258cf8ced0c29979e4f8b1f2776118abf850551d2e"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:v1.9.1-flannel1@sha256:7c3377e977b4b77b8efdad96e207ebee371537d6dcd7b9c40853cf0c0f0aade3"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.2.1@sha256:49b77655f9f109bedc5eb25723bb0e4c57d8513ba33cc69c31be3f243eb2386d"
    minio              = "cgr.dev/chainguard/minio:latest@sha256:f767919bd003062ac69713cdce920eb922c9fa3388efe96264e78b763342ca1a"
    # tier 2
    kea               = "reg.cluster.internal/randomcoww/kea:v3.2.0.1784556033@sha256:5ba20e2ae2eb90e006cd70a808cc1cf3376e41538dc5d6ecd3d644f2e0faf8a1"
    ipxe              = "reg.cluster.internal/randomcoww/ipxe:v2.0.0.1784556701@sha256:c379e96ab3e875ad9b35907d304c8fc4cd9c2fabe6905a271c3804ed26836581"
    registry          = "ghcr.io/distribution/distribution:3.1.1@sha256:bca24727f4002e51f959c18c42e816e4d1078198081a9837e16b8b7d7e43ebf8"
    device_plugin     = "ghcr.io/squat/generic-device-plugin:0.2.0@sha256:66c8d5c270eb2b721f1064c549b9b7898152a6d2f0163380a5d37dc7636c20ff"
    gha_runner        = "ghcr.io/actions/actions-runner:2.336.0@sha256:0cfdcc701ce933c6d243c6b0b2da767366dc9f2e99961d4c3754b0b78084cdda"
    mountpoint_s3_csi = "reg.cluster.internal/randomcoww/mountpoint-s3-csi:v2.7.0.1784555222@sha256:2cea71465d557f45b9ecd28d73dbf1b8a3a7a42861250d527338be2716112b51"
    # tier 3
    hostapd          = "reg.cluster.internal/randomcoww/hostapd:v2.11.1784555602@sha256:798ac8339499ffbcb09e8f0776f88e73a5c963eecbfedbfb836192bbfb6b80cc"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v1784562851@sha256:d4140ca16b874f2ebc8288c2244c941ea2404bc2fca2cb44a2afde948fddb8bb"
    llama_cpp_vulkan = "reg.cluster.internal/randomcoww/llama-swap-ffmpeg:unified-vulkan-2026-07-19.1784555119@sha256:7af85428f3f6738a380c5d9d3f2643e2e15d86925797ab47c58a4e4c9169fe4c"
    litestream       = "docker.io/litestream/litestream:0.5.14@sha256:ef0ac5958cf81725b7a85fb76f82ef71ace030db9429086eeefc59ee6ca53941"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:b8ca38ba06eea544d7555e88321e212ddc0d5c3c7de055419cfb2e5c6bf30812"
    lldap            = "ghcr.io/lldap/lldap:v0.6.3-alpine-rootless@sha256:ba2c50930ea998eefd5454aa678a7977448019248b1827da87d330df0b71c284"
    authelia         = "ghcr.io/authelia/authelia:4.39.20@sha256:1b363e9279e742397966333f364e0876ae02bf5c876de73e83af6d48c57ff51b"
    cloudflared      = "docker.io/cloudflare/cloudflared:2026.7.2@sha256:4f6655284ab3d252b7f28fedb19fe6c8fc82ee5b1295c20ac74d475e5398a52d"
    kubernetes_mcp   = "ghcr.io/containers/kubernetes-mcp-server:v0.0.65@sha256:5df586e2c7ced2a3125f6e78923388d80b69de0a2ad1470325b05318f12725bd"
    camofox_browser  = "ghcr.io/jo-inc/camofox-browser:1.13.0@sha256:64b30ffdbbc4ae0e28200a66dfbd6f55ac4188229eb34ef769afcf7be40faa6e"
    navidrome        = "ghcr.io/navidrome/navidrome:0.63.2@sha256:9012939114fbb1bb641b81cf96dec5ded15f0aafefe8d47a511d7cb919658e40"
    valkey           = "ghcr.io/valkey-io/valkey:9.1-alpine@sha256:c9b77919daeba2c02ad954d0c844cc4e7142069d177b89c5fd771f405daf9e02"
    thanos           = "quay.io/thanos/thanos:v0.42.2@sha256:6249f7aaadd3695df637fb2eb4cb9a9955611eee691c3970892fe9c0dc3f2db6"
    stump            = "docker.io/aaronleopold/stump:0.1.5@sha256:02684fe218a2a54aee5e8bedd8306b971b857d562770ebc3c35400a706845b6e"
    hermes_agent     = "reg.cluster.internal/randomcoww/hermes-mnemosyne:v2026.7.20.1784591297@sha256:ce3d08064776a6ca7cc96ae9f093b4588728cba2ab8f56ead07f513c06448eeb"
    hermes_webui     = "ghcr.io/nesquena/hermes-webui:0.52.136@sha256:49f9d97ce7d8f509f6d38b27173fe8ecd4f3f21318b0d5b00b503fb756c12df6"
    juicefs          = "reg.cluster.internal/randomcoww/juicefs:ce-v1.4.0.1784556524@sha256:96a5b2b03f1858bc03177a011305075dba3ead2c9ac4eb913eff69edddbb30f6"

    # models (model_file)
    "Qwen3.6-27B-BF16-00001-of-00002.gguf"                               = "reg.cluster.internal/randomcoww/qwen3.6-27b-bf16:v1783465086@sha256:48415dda9b84ae3de638c7e218d69e1feb56db51b966cf65eac18f9fafad7486"
    "Qwen3.6-27B-mmproj-BF16.gguf"                                       = "reg.cluster.internal/randomcoww/qwen3.6-27b-bf16:v1783465086@sha256:48415dda9b84ae3de638c7e218d69e1feb56db51b966cf65eac18f9fafad7486"
    "gemma-4-31B-it-BF16-00001-of-00002.gguf"                            = "reg.cluster.internal/randomcoww/gemma-4-31b-it-bf16:v1783493322@sha256:0df8bc92746e34aefffc89708257c576743abc2577d4454d176e9af044a54e60"
    "gemma-4-31B-it-BF16-MTP.gguf"                                       = "reg.cluster.internal/randomcoww/gemma-4-31b-it-bf16:v1783493322@sha256:0df8bc92746e34aefffc89708257c576743abc2577d4454d176e9af044a54e60"
    "gemma-4-31B-it-mmproj-BF16.gguf"                                    = "reg.cluster.internal/randomcoww/gemma-4-31b-it-bf16:v1783493322@sha256:0df8bc92746e34aefffc89708257c576743abc2577d4454d176e9af044a54e60"
    "ggml-large-v3-turbo-q8_0.bin"                                       = "reg.cluster.internal/randomcoww/whisper-large-v3-turbo-q8-0:v1781645858@sha256:b6ddc70ec2752d59bbaaa936ec2ae6e4ee1e5a5ced5fb4cd8d77e4a272585039"
    "jina-reranker-m0-Q8_0.gguf"                                         = "reg.cluster.internal/randomcoww/jina-reranker-m0-q8-0:v1781726556@sha256:ffd55a7d9f41eb7fe6971997e660a59faf265fd50a39bf999d8057d0146e4656"
    "jina-embeddings-v5-omni-small-text-matching-Q8_0.gguf"              = "reg.cluster.internal/randomcoww/jina-embeddings-v5-omni-small-text-matching-q8-0:v1781728112@sha256:21c5b33ae3bc351542d97bd312d002fbe127d954608bd5b56a0c5bc711fabd54"
    "jina-embeddings-v5-omni-small-text-matching-audio-mmproj-F16.gguf"  = "reg.cluster.internal/randomcoww/jina-embeddings-v5-omni-small-text-matching-q8-0:v1781728112@sha256:21c5b33ae3bc351542d97bd312d002fbe127d954608bd5b56a0c5bc711fabd54"
    "jina-embeddings-v5-omni-small-text-matching-vision-mmproj-F16.gguf" = "reg.cluster.internal/randomcoww/jina-embeddings-v5-omni-small-text-matching-q8-0:v1781728112@sha256:21c5b33ae3bc351542d97bd312d002fbe127d954608bd5b56a0c5bc711fabd54"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      default = "44.20260720.20.1.1784599926" # renovate: datasource=github-tags depName=randomcoww/fedora-coreos-config-custom
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
    kubelet            = 10250 # prometheus operator assumes this port and is not configurable
    kube_proxy         = 50254
    kube_proxy_metrics = 50255
    etcd_client        = 58082
    etcd_peer          = 58083
    etcd_metrics       = 58086
    flannel_healthz    = 58084
    bgp                = 179 # not configurable
    kube_vip_metrics   = 58089
    crio_metrics       = 58091
  }

  service_ports = {
    minio           = 9000
    coredns_metrics = 9153
    registry        = 443 # not configurable
    ldaps           = 6360
    redis_sentinel  = 26379
    kubernetes_mcp  = 8080
  }

  ha = {
    keepalived_config_path = "/etc/keepalived/keepalived.conf.d"
    haproxy_config_path    = "/etc/haproxy/haproxy.cfg.d"
    bird_config_path       = "/etc/bird.conf.d"
    bird_cache_table_name  = "cache"
    bgp_as                 = 65005
  }

  domain_regex = "(?<hostname>(?<subdomain>[a-z0-9-*]+)\\.(?<domain>[a-z0-9.-]+))(?::(?<port>\\d+))?"
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
      ClusterTrustBundle                      = true
      ClusterTrustBundleProjection            = true
      InPlacePodLevelResourcesVerticalScaling = false # TODO: workaround for kubelet 1.36.x panic with doPodResizeAction
    }
  }

  endpoints = {
    for name, e in {
      kube_proxy = {
        name      = "kube-proxy"
        namespace = "kube-system"
      }
      etcd = {
        name      = "etcd"
        namespace = "kube-system"
      }
      kube_dns = {
        name      = "kube-dns"
        namespace = "kube-system"
      }
      traefik = {
        name      = "traefik"
        namespace = "traefik"
      }
      kubernetes_mcp = {
        name = "kubernetes-mcp"
      }
      mountpoint_s3_csi = {
        name      = "s3-csi"
        namespace = "s3-csi"
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
        name      = "registry"
        namespace = "registry"
        service   = "reg.${local.domains.kubernetes}"
      }
      qrcode_hostapd = {
        name    = "qrcode-hostapd"
        ingress = "hostapd.${local.domains.public}"
      }
      llama_cpp = {
        name = "llama-cpp"
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
      navidrome = {
        name = "navidrome"
      }
      stump = {
        name   = "stump"
        tunnel = true
      }
      fluxcd = {
        name      = "fluxcd"
        namespace = "flux-system"
      }
      cert_manager = {
        name      = "cert-manager"
        namespace = "cert-manager"
      }
      camofox_browser = {
        name = "camofox"
      }
      hermes_agent = {
        name = "hermes-agent"
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
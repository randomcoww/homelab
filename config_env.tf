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
    etcd                    = "registry.k8s.io/etcd:v3.6.13@sha256:24fc96ede8e787eb769e771d1245ddb2333301697a8b571e20415a0caccc375e"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.5.31@sha256:b3349d42a116d7406bfde97b41f2fff80696e5ffc35ce5e6571b9b441901b386"
    # tier 1
    kube_proxy         = "registry.k8s.io/kube-proxy:v1.36.2@sha256:620a27c742eb5ebf5be8613b7458b7ce7cd31e2804b61b98f6516e328002c4cc"
    flannel            = "ghcr.io/flannel-io/flannel:v0.28.5@sha256:5414132a5547ca336112dc00113530363aeeb7e8b59c1f6b8e5703c0ccb534e7"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:v1.9.1-flannel1@sha256:7c3377e977b4b77b8efdad96e207ebee371537d6dcd7b9c40853cf0c0f0aade3"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.2.1@sha256:49b77655f9f109bedc5eb25723bb0e4c57d8513ba33cc69c31be3f243eb2386d"
    minio              = "cgr.dev/chainguard/minio:latest@sha256:a74b2956ce2c0e965c3a0e7e8a8de14b34daa760ea72b39a22552e37859b756a"
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.31.2-alpine@sha256:a8d5564c3354241473c1e152d5dd3281ab4224edb61b23c291e0bfd9854687a1"
    # tier 2
    kea           = "reg.cluster.internal/randomcoww/kea:v3.1.9.1782147096@sha256:02acda614b50e73f8ecf829249ed751868d02e56c803186abf862ab42230781c"
    ipxe          = "reg.cluster.internal/randomcoww/ipxe:v2.0.0.1782748352@sha256:8e4df2791dd35cd6fd87697ed8fd35b7e19b15234f4f1e88e68c9fb4eac7db2c"
    registry      = "ghcr.io/distribution/distribution:3.1.1@sha256:bca24727f4002e51f959c18c42e816e4d1078198081a9837e16b8b7d7e43ebf8"
    device_plugin = "ghcr.io/squat/generic-device-plugin:0.2.0@sha256:66c8d5c270eb2b721f1064c549b9b7898152a6d2f0163380a5d37dc7636c20ff"
    gha_runner    = "ghcr.io/actions/actions-runner:2.335.1@sha256:08c30b0a7105f64bddfc485d2487a22aa03932a791402393352fdf674bda2c29"
    # tier 3
    mountpoint       = "reg.cluster.internal/randomcoww/mountpoint-s3:v1.22.3.1782747688@sha256:877b210fdd08e65c488da21e3275a1655bb4642851bf73ac838bf026cb3eda34"
    hostapd          = "reg.cluster.internal/randomcoww/hostapd:v2.11.1782747376@sha256:76a9f005484f45e504604d96ad5520c68ff73380519bdf56637bd9d1c27a6f42"
    tailscale        = "ghcr.io/tailscale/tailscale:v1.98.4@sha256:25cde9ad76020b0e29229136d0c38b5962e9a0e1774ffac9b0df68e4a37d6cf0"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v1782747012@sha256:ada388e04c2de4f0e894a9ecd0fcce78423a1c6141eb360f07832c236cc5665b"
    llama_cpp_vulkan = "reg.cluster.internal/randomcoww/llama-swap-ffmpeg:unified-vulkan-2026-06-15.1781583535@sha256:c3b4524709cf2092da6411f9042939c78dbf784e663d613a8cefeb7e0338adde"
    litestream       = "docker.io/litestream/litestream:0.5.13@sha256:63134c853e43c12bf5b08aa93f0fae4dd63c7034b0972d626817ad562e6a8609"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:33aa33278be6c0be379b95f7c91cd455c18141295291c2e5a396454761df7bbb"
    open_webui       = "ghcr.io/open-webui/open-webui:v0.10.2@sha256:9fcea9c6e32ab60b0498f3986c6cdf651ddbe61db48d2213a3d28048ddd673d4"
    lldap            = "ghcr.io/lldap/lldap:v0.6.3-alpine-rootless@sha256:ba2c50930ea998eefd5454aa678a7977448019248b1827da87d330df0b71c284"
    authelia         = "ghcr.io/authelia/authelia:4.39.20@sha256:1b363e9279e742397966333f364e0876ae02bf5c876de73e83af6d48c57ff51b"
    cloudflared      = "docker.io/cloudflare/cloudflared:2026.6.1@sha256:6d91c121b803126f7a5344005d17a9324788fc09d305b6e2560ec6040a7ae283"
    kubernetes_mcp   = "ghcr.io/containers/kubernetes-mcp-server:v0.0.63@sha256:9317449ed47916a297f71b955eab57402064de852bf1fb007c4e0705754de2b3"
    camofox_browser  = "ghcr.io/jo-inc/camofox-browser:1.11.2@sha256:826da04c4ec75b3eb450bc7cf2513176ba408f92b862b89f768ca30563171137"
    navidrome        = "ghcr.io/navidrome/navidrome:0.62.0@sha256:c4b5cb36a790b3eb63ca6a68bbe2fe149c2d7fa2e586f7a480e61db630e6664b"
    valkey           = "ghcr.io/valkey-io/valkey:9.1-alpine@sha256:a35428eba9043cc0b79dbe54100f0c92784f2de00ad09b01182bfb1c5c83d1bd"
    thanos           = "quay.io/thanos/thanos:v0.41.0@sha256:cf3e9b292e4302ad4a4955b56379703aea39516607d382a57604a3d003c35d10"
    stump            = "docker.io/aaronleopold/stump:0.1.5@sha256:02684fe218a2a54aee5e8bedd8306b971b857d562770ebc3c35400a706845b6e"
    hermes_agent     = "reg.cluster.internal/randomcoww/hermes-mnemosyne:v2026.6.5.1782746926@sha256:d8e06bab54658be3bb1f414270372654a0e2ce193871c6d7935c58edc1e80f26"
    juicefs          = "reg.cluster.internal/randomcoww/juicefs:v1.3.1.1782748221@sha256:a252445b4a4160c8b2e7ed897cbd36d1dad6b2bf8cbe970bc0e273d786892e04"

    # models (model_file)
    "NVIDIA-Nemotron-3-Super-120B-A12B-MXFP4_MOE-00001-of-00003.gguf"    = "reg.cluster.internal/randomcoww/nvidia-nemotron-3-super-120b-a12b-mxfp4-moe:v1773610375@sha256:7c5065d9e53b4752fd40b496cd287946f5f5e5308ad29bfdea81c0622de6da0f"
    "NVIDIA-Nemotron-3-Nano-Omni-30B-A3B-Reasoning-UD-Q8_K_XL.gguf"      = "reg.cluster.internal/randomcoww/nvidia-nemotron-3-nano-omni-30b-a3b-reasoning-ud-q8-k-xl:v1777546075@sha256:44827b5c42b7bccbf22fb4dc4de0c2b3880cadd8f354dbd4a1a21c90de7389a3"
    "mmproj-F16.gguf"                                                    = "reg.cluster.internal/randomcoww/nvidia-nemotron-3-nano-omni-30b-a3b-reasoning-ud-q8-k-xl:v1777546075@sha256:44827b5c42b7bccbf22fb4dc4de0c2b3880cadd8f354dbd4a1a21c90de7389a3"
    "ggml-large-v3-turbo-q8_0.bin"                                       = "reg.cluster.internal/randomcoww/whisper-large-v3-turbo-q8-0:v1781645858@sha256:b6ddc70ec2752d59bbaaa936ec2ae6e4ee1e5a5ced5fb4cd8d77e4a272585039"
    "jina-reranker-m0-Q8_0.gguf"                                         = "reg.cluster.internal/randomcoww/jina-reranker-m0-q8-0:v1781726556@sha256:ffd55a7d9f41eb7fe6971997e660a59faf265fd50a39bf999d8057d0146e4656"
    "jina-embeddings-v5-omni-small-text-matching-Q8_0.gguf"              = "reg.cluster.internal/randomcoww/jina-embeddings-v5-omni-small-text-matching-q8-0:v1781728112@sha256:21c5b33ae3bc351542d97bd312d002fbe127d954608bd5b56a0c5bc711fabd54"
    "jina-embeddings-v5-omni-small-text-matching-audio-mmproj-F16.gguf"  = "reg.cluster.internal/randomcoww/jina-embeddings-v5-omni-small-text-matching-q8-0:v1781728112@sha256:21c5b33ae3bc351542d97bd312d002fbe127d954608bd5b56a0c5bc711fabd54"
    "jina-embeddings-v5-omni-small-text-matching-vision-mmproj-F16.gguf" = "reg.cluster.internal/randomcoww/jina-embeddings-v5-omni-small-text-matching-q8-0:v1781728112@sha256:21c5b33ae3bc351542d97bd312d002fbe127d954608bd5b56a0c5bc711fabd54"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      default = "44.20260612.20.1.1781297721" # renovate: datasource=github-tags depName=randomcoww/fedora-coreos-config-custom
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
    kubernetes_mcp = 8080
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
      kured = {
        name      = "kured"
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
      llama_cpp_s = {
        name = "llama-cpp-s" # small models
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
      navidrome = {
        name = "navidrome"
      }
      stump = {
        name   = "stump"
        tunnel = true
      }
      kubernetes_mcp = {
        name = "kubernetes-mcp"
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
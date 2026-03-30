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
    etcd                    = "registry.k8s.io/etcd:v3.6.9@sha256:38e46ab26aa2a82251d3f24cbbdaefe2e68a66346404ee4b7afe7e90db26805d"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.5.28@sha256:e7291e59be84f8b2ac2be25604922b01c7cbc6b474b5f26e15c48dfb777997f8"
    # tier 1
    kube_proxy         = "registry.k8s.io/kube-proxy:v1.35.3@sha256:8743aec6a360aedcb7a076cbecea367b072abe1bfade2e2098650df502e2bc89"
    flannel            = "ghcr.io/flannel-io/flannel:v0.28.2@sha256:3726b7dd2f758f1cc8155edc442e7f3fbad68cf42530d6bcb3ddffdba40a1394"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:v1.9.0-flannel1@sha256:c6a08fe5bcb23b19c2fc7c1e47b95a967cc924224ebedf94e8623f27b6c258fa"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.1.1@sha256:87e88b44edc98f0079eac3e03b2ec4de9bde6ea100acd27a63e738d23b9aedbc"
    minio              = "cgr.dev/chainguard/minio:latest@sha256:e395c92a38f44238f3d4f21b55af0a17328e04ab3c31b8825a7b457f8d69618a"
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.29.5-alpine@sha256:f99cc61bf1719f30230602036314ff6ba5dcede8965c5ed3ded71b8bbced3723"
    # tier 2
    kea           = "ghcr.io/randomcoww/kea:v3.1.7@sha256:c35219e5417884fa64d68d5c923fbbea40c036d9f86039bccad8b4bc8d5ec2b0"
    ipxe          = "ghcr.io/randomcoww/ipxe:v2.0.0@sha256:7fba96b92dcdccb93b4d823fd126a06d9a8169cb34cc5832ea33ce3b2153ccf6"
    registry      = "ghcr.io/distribution/distribution:3.0.0@sha256:4ba3adf47f5c866e9a29288c758c5328ef03396cb8f5f6454463655fa8bc83e2"
    device_plugin = "ghcr.io/squat/generic-device-plugin:latest@sha256:e85f9637ea93f0e9a8d477b0e136783cd6fb8f1a5426cf84ef05ab4c88661c8c"
    gha_runner    = "ghcr.io/actions/actions-runner:2.333.1@sha256:b57864c9fcda15ea4a270446aa9cfb108b819a26f6e71fc515f6caf6c27989c6"
    # tier 3
    mountpoint       = "reg.cluster.internal/randomcoww/mountpoint-s3:v1.22.2.1774883529@sha256:d5c61d682dd7931413ea5cd649194eb30afacc1097e0daaa8f951c2953baab90"
    hostapd          = "reg.cluster.internal/randomcoww/hostapd:v2.11.1774882541@sha256:4e836087ab10ea4024f3e2507a5d8e959d38cde42261fa6b2d185c975a69a712"
    tailscale        = "ghcr.io/tailscale/tailscale:v1.94.2@sha256:95e528798bebe75f39b10e74e7051cf51188ee615934f232ba7ad06a3390ffa1"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v1774277541@sha256:a4d05cf7cc0dd9af70590247957119b0a907e6ae3eccd71105ef341bcb18f966"
    llama_cpp_vulkan = "ghcr.io/mostlygeek/llama-swap:vulkan@sha256:0ff5777c3471e71b604139717bd2cbff1d144fe766c88f290421339407bfb619"
    litestream       = "docker.io/litestream/litestream:0.5.10@sha256:66c0ef32779b20f7ce682751ec50ba0f1363cad5cb9dba1e23fbeee6ae3197b9"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:4d7ed8b7035ecf827bd901ba6d32f5c32d8119bc09bb3cdafeb0ce58f1b951c1"
    open_webui       = "ghcr.io/open-webui/open-webui:v0.8.12@sha256:8113fa5510020ef05a44afc0c42d33eabeeb2524a996e3e3fb8c437c00f0d792"
    kavita           = "ghcr.io/kareadita/kavita:0.8.9@sha256:1f2acae7466d022f037ea09f7989eb7c487f916b881174c7a6de33dbfa8acb39"
    lldap            = "ghcr.io/lldap/lldap:latest-alpine@sha256:af6daf88e67b2c6885d2426f711cb241751b515cc36a995d36ba77f2ffd199fb"
    authelia         = "ghcr.io/authelia/authelia:4.39.16@sha256:edbce01c5125249e4f4faea01e0f76f0031d64b4a1d0c2514a0ca69cb126d05f"
    cloudflared      = "docker.io/cloudflare/cloudflared:2026.3.0@sha256:6b599ca3e974349ead3286d178da61d291961182ec3fe9c505e1dd02c8ac31b0"
    sunshine_desktop = "reg.cluster.internal/randomcoww/sunshine-desktop:v2026.329.31930.1774882930@sha256:ec39e88ea74ce524c82f6cc16394e58256780314db90ab76ef245f8839ec2459"
    kubernetes_mcp   = "ghcr.io/containers/kubernetes-mcp-server:latest@sha256:015dfa440a2f1e8d26ac79b1dbef559f1d1aee62331116521b706b4e275e253d"
    navidrome        = "ghcr.io/navidrome/navidrome:0.60.3@sha256:a5dce8f33304714dd138e870cca0dcab3d937ca236be1a9f2b97da009d1a0048"
    valkey           = "ghcr.io/valkey-io/valkey:9.1-alpine@sha256:355ae2c6c965769a0d9b9810711e6befd5b79fe676d1faa848247733ad6a4408"

    # models (model_file)
    "v5-small-text-matching-Q8_0.gguf"                                = "reg.cluster.internal/randomcoww/jina-embeddings-v5-text-small-text-matching-q8-0:v1773615151@sha256:ead9710eb051ea3b6ee32cebc1d1a8ba782c9e589ea972b48b15c173e169c4ee"
    "jina-reranker-v3-Q8_0.gguf"                                      = "reg.cluster.internal/randomcoww/jina-reranker-v3-q8-0:v1773185353@sha256:f9f985cd629f0a3f39d07de317545bb733ca14148f31040d567d267a8364ab4f"
    "NVIDIA-Nemotron-3-Super-120B-A12B-MXFP4_MOE-00001-of-00003.gguf" = "reg.cluster.internal/randomcoww/nvidia-nemotron-3-super-120b-a12b-mxfp4-moe:v1773610375@sha256:7c5065d9e53b4752fd40b496cd287946f5f5e5308ad29bfdea81c0622de6da0f"
    "GLM-4.7-Flash-Q8_0.gguf"                                         = "reg.cluster.internal/randomcoww/glm-4.7-flash-q8-0:v1773627383@sha256:1b2e6d762b1c003cbf5a2b79ea3a15fd309d436fdcb9229d3819a39366cb8645"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      default = "43.20260327.20.1.1774632529" # renovate: datasource=github-tags depName=randomcoww/fedora-coreos-config-custom
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
      kavita = {
        name   = "kavita"
        tunnel = true
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
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
    kube_apiserver          = "registry.k8s.io/kube-apiserver:v1.36.0@sha256:4ae8c24a97630f8cfc9eed02fb95e2371d172bb231915e83d27f6ea0e64fa297"
    kube_controller_manager = "registry.k8s.io/kube-controller-manager:v1.36.0@sha256:886b5c5623206b7bddf0303484cf632e3f5514a20ef1a1b685f38634b42531dd"
    kube_scheduler          = "registry.k8s.io/kube-scheduler:v1.36.0@sha256:00b57dfadc2e99fe85481f56ea15f391d5447ebc3ac243896f0e7afd869ef60e"
    etcd                    = "registry.k8s.io/etcd:v3.6.10@sha256:f65c61039e7b7fd6e651f7ec2459b880589892cb13cf79c2f71c92aa08fc5144"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.5.31@sha256:b3349d42a116d7406bfde97b41f2fff80696e5ffc35ce5e6571b9b441901b386"
    # tier 1
    kube_proxy         = "registry.k8s.io/kube-proxy:v1.36.0@sha256:0585504d29fee419791fdbc36c88a9d39773376a565d6f0c688673243df139fc"
    flannel            = "ghcr.io/flannel-io/flannel:v0.28.4@sha256:cc44a1a8969c4f14b8dd45664546f14abc3fc7682b125399103e555f1ad2528b"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:v1.9.1-flannel1@sha256:7c3377e977b4b77b8efdad96e207ebee371537d6dcd7b9c40853cf0c0f0aade3"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.1.2@sha256:840305b94ef2a89abb3b7fd2b09edfbde690d90052020da4dff90679fe892da2"
    minio              = "cgr.dev/chainguard/minio:latest@sha256:a342898b433b4df054f20209980e58607f90a6ead4993424832597c65371648a"
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.30.0-alpine@sha256:35a4455cd4153d7cd0ae1fcfa42451884ef19848202606f144d9a089376c7e6c"
    # tier 2
    kea           = "ghcr.io/randomcoww/kea:v3.1.7@sha256:287237367a3813a69c487ebc9af44c2a8344c0a9bdcfbfd915e1db1e0c2822f3"
    ipxe          = "ghcr.io/randomcoww/ipxe:v2.0.0@sha256:374ca556d93abcb483ed42aefe42325e8ad947a276de487c9cdcf1771167db4c"
    registry      = "ghcr.io/distribution/distribution:3.1.0@sha256:4fdc7c11dd6b58fd06e386971bf29929eebd831a074197ad1457a1aefeacf3da"
    device_plugin = "ghcr.io/squat/generic-device-plugin:0.2.0@sha256:66c8d5c270eb2b721f1064c549b9b7898152a6d2f0163380a5d37dc7636c20ff"
    gha_runner    = "ghcr.io/actions/actions-runner:2.334.0@sha256:b6614fce332517f74d0a76e7c762fb08e4f2ff13dcf333183397c8a5725b6e8e"
    # tier 3
    mountpoint       = "reg.cluster.internal/randomcoww/mountpoint-s3:v1.22.2.1777305161@sha256:f1f7369bcf84e18b2870f1d8c658e0c7716242c6aacc2e2e32a685039f51784a"
    hostapd          = "reg.cluster.internal/randomcoww/hostapd:v2.11.1777303691@sha256:79bbe254117a346a37331a64b6aaea62ec5b3187803380bbbb8fe8eb429785b9"
    tailscale        = "ghcr.io/tailscale/tailscale:v1.96.5@sha256:dbeff02d2337344b351afac203427218c4d0a06c43fc10a865184063498472a6"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v1777304706@sha256:ff22a89807abd9be366282d9c44ac1082502f3d7b25d25920d3713f1fb7f805b"
    llama_cpp_vulkan = "ghcr.io/mostlygeek/llama-swap:vulkan@sha256:53e09d2f11696b7ec1e8ec928486518fdf4dbd260774fad77a553c4251efff50"
    litestream       = "docker.io/litestream/litestream:0.5.11@sha256:79e3bfce6ed758722916f816b028fffd9e0a971058f41b88e2779510cead1d8d"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:ba3fbb767c9dcc29509fcbef00268a3a5d3535ed57e19a7582a56058f8b2c5c4"
    open_webui       = "ghcr.io/open-webui/open-webui:v0.9.2@sha256:a7e4796ae894d1e2a0c1824860ade472f35c507608a01c3581377b5c19b0ed49"
    lldap            = "ghcr.io/lldap/lldap:latest-alpine@sha256:af6daf88e67b2c6885d2426f711cb241751b515cc36a995d36ba77f2ffd199fb"
    authelia         = "ghcr.io/authelia/authelia:4.39.19@sha256:0c824dcab1ae97c56bf673c5e77fe8cc6bcd400564555140cc8002a12c6b6463"
    cloudflared      = "docker.io/cloudflare/cloudflared:2026.3.0@sha256:6b599ca3e974349ead3286d178da61d291961182ec3fe9c505e1dd02c8ac31b0"
    sunshine_desktop = "reg.cluster.internal/randomcoww/sunshine-desktop:v2026.423.21833.1777304796@sha256:e532afec789e5262a5c6fca09d713407d2e102dcacac503038d7e51eea0737a5"
    kubernetes_mcp   = "ghcr.io/containers/kubernetes-mcp-server:latest@sha256:96d8b3310b5bd2622ae31ecc3d5a249eeaddd4c28e6734b657e80b7249bd5276"
    prometheus_mcp   = "ghcr.io/pab1it0/prometheus-mcp-server:1.6.0@sha256:06259d8cc17469edd79989fd4b9de57cec7afb028e1469c02ebada6a952de5e1"
    navidrome        = "ghcr.io/navidrome/navidrome:0.61.2@sha256:9fa40b3d8dec43ceb2213d1fa551da3dcfef6ac6d19c2e534efb92527c2bafd2"
    valkey           = "ghcr.io/valkey-io/valkey:9.1-alpine@sha256:355ae2c6c965769a0d9b9810711e6befd5b79fe676d1faa848247733ad6a4408"
    thanos           = "quay.io/thanos/thanos:v0.41.0@sha256:cf3e9b292e4302ad4a4955b56379703aea39516607d382a57604a3d003c35d10"
    stump            = "docker.io/aaronleopold/stump:0.1.2@sha256:70594ad1e65d62663c47cd2ffb1a6e7367962a6a878889f4c5beeb81387c95d6"
    camoufox         = "reg.cluster.internal/randomcoww/camoufox:v0.4.11.1777303811@sha256:a09592ba21fc04ea8b61677b649d6b8b3def3960c452a4e4609631e4d683e746"

    # models (model_file)
    "v5-small-text-matching-Q8_0.gguf"                                = "reg.cluster.internal/randomcoww/jina-embeddings-v5-text-small-text-matching-q8-0:v1773615151@sha256:ead9710eb051ea3b6ee32cebc1d1a8ba782c9e589ea972b48b15c173e169c4ee"
    "jina-reranker-v3-Q8_0.gguf"                                      = "reg.cluster.internal/randomcoww/jina-reranker-v3-q8-0:v1773185353@sha256:f9f985cd629f0a3f39d07de317545bb733ca14148f31040d567d267a8364ab4f"
    "NVIDIA-Nemotron-3-Super-120B-A12B-MXFP4_MOE-00001-of-00003.gguf" = "reg.cluster.internal/randomcoww/nvidia-nemotron-3-super-120b-a12b-mxfp4-moe:v1773610375@sha256:7c5065d9e53b4752fd40b496cd287946f5f5e5308ad29bfdea81c0622de6da0f"
    "GLM-4.7-Flash-Q8_0.gguf"                                         = "reg.cluster.internal/randomcoww/glm-4.7-flash-q8-0:v1773627383@sha256:1b2e6d762b1c003cbf5a2b79ea3a15fd309d436fdcb9229d3819a39366cb8645"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      default = "43.20260423.20.1.1776930262" # renovate: datasource=github-tags depName=randomcoww/fedora-coreos-config-custom
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
        name = "navidrome"
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
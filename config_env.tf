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
        apiserver        = 2
        k8s_gateway      = 31
        minio            = 34
        registry         = 35 # used by hosts without access to cluster DNS
        gateway_api      = 36
        sunshine_desktop = 37
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
    kube_apiserver          = "registry.k8s.io/kube-apiserver:v1.36.1@sha256:2460df74307cafacf674573c88df511aeb1aece9daa7fbd968fe27cb1c8c4588"
    kube_controller_manager = "registry.k8s.io/kube-controller-manager:v1.36.1@sha256:c8adb8daee5b30576bd87638a89351ab8388b3fda466bedb7eacf10cde77dbe7"
    kube_scheduler          = "registry.k8s.io/kube-scheduler:v1.36.1@sha256:3a4333e8ba6e1f74c9bc467c791a06a26808474e8819582cf130cfe0fddc3155"
    etcd                    = "registry.k8s.io/etcd:v3.6.12@sha256:3c2ced08f23b1183e8bd4613064c3fb6b8db5057a4d1f13c3518c76e357a07a8"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.5.31@sha256:b3349d42a116d7406bfde97b41f2fff80696e5ffc35ce5e6571b9b441901b386"
    # tier 1
    kube_proxy         = "registry.k8s.io/kube-proxy:v1.36.1@sha256:a96b6e12863ef766d18f69afaad7a5329220c37ce21cb232bcb58362d284f3f7"
    flannel            = "ghcr.io/flannel-io/flannel:v0.28.5@sha256:5414132a5547ca336112dc00113530363aeeb7e8b59c1f6b8e5703c0ccb534e7"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:v1.9.1-flannel1@sha256:7c3377e977b4b77b8efdad96e207ebee371537d6dcd7b9c40853cf0c0f0aade3"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.2.0@sha256:fe8c7b6641ba7633a12b337821e9e83a6456e8edc3434f97577058edd4eecaf6"
    minio              = "docker.io/pgsty/minio:RELEASE.2026-04-17T00-00-00Z@sha256:83885c27b3b5b673049e33ddf4029afe2c134fd51ce4309e65e4f39d3b9ca282"
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.31.1-alpine@sha256:85bcbc6b2edd325462560c597d784ecee415024f1c6a004e53ac5f202b8ca561"
    # tier 2
    kea           = "reg.cluster.internal/randomcoww/kea:v3.1.9.1780933561@sha256:c46b6bb41736fcdac66dd9ecf39802b9809060a6c247a378e700261181b4d5e7"
    ipxe          = "reg.cluster.internal/randomcoww/ipxe:v2.0.0.1780934327@sha256:589a8a6e7dbcdf6152168fd3024acb679039b628dfbb85dd642ef7cef8247ce8"
    registry      = "ghcr.io/distribution/distribution:3.1.1@sha256:bca24727f4002e51f959c18c42e816e4d1078198081a9837e16b8b7d7e43ebf8"
    device_plugin = "ghcr.io/squat/generic-device-plugin:0.2.0@sha256:66c8d5c270eb2b721f1064c549b9b7898152a6d2f0163380a5d37dc7636c20ff"
    gha_runner    = "ghcr.io/actions/actions-runner:2.335.1@sha256:08c30b0a7105f64bddfc485d2487a22aa03932a791402393352fdf674bda2c29"
    # tier 3
    mountpoint       = "reg.cluster.internal/randomcoww/mountpoint-s3:v1.22.3.1780933475@sha256:c9e47647166e74e4cc5ca2c084230a5535ded13fd480dfbdbe079dcca505c797"
    hostapd          = "reg.cluster.internal/randomcoww/hostapd:v2.11.1780933079@sha256:d00ff51814dfd12589daacf950352af9591bccd74d7de4ccf0d17d15697c75cc"
    tailscale        = "ghcr.io/tailscale/tailscale:v1.98.4@sha256:25cde9ad76020b0e29229136d0c38b5962e9a0e1774ffac9b0df68e4a37d6cf0"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v1780932531@sha256:4fb4193e5a7652bf1c3bbe31b12caad96c475bf78deb3b3c9ff15dc5bc46cb5c"
    llama_cpp_vulkan = "ghcr.io/mostlygeek/llama-swap:unified-vulkan@sha256:edb6dee6968223e9afde2b05229648bcfb14d5cda0b0df1430e489ec84a02651"
    litestream       = "docker.io/litestream/litestream:0.5.12@sha256:dfbb4d91b3d6f50f3185f29f5abb25118d00053de3fc6a45f4a399bc859f4e0f"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:02d441bbb647b7be422d21041420115cddadac4644368f67c7c7f407bbe72e22"
    open_webui       = "ghcr.io/open-webui/open-webui:v0.9.6@sha256:90eae5b419e40b4c3dd684582b2c83440b36f9ae2f6532c09639b2ba4ee65158"
    lldap            = "ghcr.io/lldap/lldap:v0.6.3-alpine-rootless@sha256:ba2c50930ea998eefd5454aa678a7977448019248b1827da87d330df0b71c284"
    authelia         = "ghcr.io/authelia/authelia:4.39.20@sha256:1b363e9279e742397966333f364e0876ae02bf5c876de73e83af6d48c57ff51b"
    cloudflared      = "docker.io/cloudflare/cloudflared:2026.6.0@sha256:ba461b8aa9c042156dbd39c38657fe7431bafa063220eab8d5330a523863da9f"
    sunshine_desktop = "reg.cluster.internal/randomcoww/sunshine-desktop:v2026.605.170308.1780933552@sha256:84727518e74a1fe701d0b498e18d755995a6fc4fe315c764d290f63d4f99ca20"
    mcp_proxy        = "ghcr.io/tbxark/mcp-proxy:v0.43.2@sha256:70c0e02d39c4c0898e610b3a30954f7930628fa6f4fb447bad14c32382a25879"
    kubernetes_mcp   = "ghcr.io/containers/kubernetes-mcp-server:v0.0.62@sha256:bd7e9ff49b0941ff230508dfceb87162c4a2be67b180c28f5d1b204fc58fa2e9"
    prometheus_mcp   = "ghcr.io/pab1it0/prometheus-mcp-server:1.6.1@sha256:ed91f3f9e4f6fb92c5b8fd48a29f3382c11498de405f59da5eac16398d47d43b"
    searxng_mcp      = "docker.io/isokoliuk/mcp-searxng:1.3.1@sha256:e812f7f3d907503f67d4e1188be5f98e36f696df608997d4107fadd7cfb62527"
    camofox_browser  = "ghcr.io/jo-inc/camofox-browser:1.11.2@sha256:826da04c4ec75b3eb450bc7cf2513176ba408f92b862b89f768ca30563171137"
    camofox_mcp      = "ghcr.io/redf0x1/camofox-mcp:1.14.4@sha256:dea7e0ce1a4e1434c31a1e669725cd9b664880174b9a20747582e19d90b30183"
    navidrome        = "ghcr.io/navidrome/navidrome:0.62.0@sha256:c4b5cb36a790b3eb63ca6a68bbe2fe149c2d7fa2e586f7a480e61db630e6664b"
    valkey           = "ghcr.io/valkey-io/valkey:9.1-alpine@sha256:a35428eba9043cc0b79dbe54100f0c92784f2de00ad09b01182bfb1c5c83d1bd"
    thanos           = "quay.io/thanos/thanos:v0.41.0@sha256:cf3e9b292e4302ad4a4955b56379703aea39516607d382a57604a3d003c35d10"
    stump            = "docker.io/aaronleopold/stump:0.1.4@sha256:09a3bfbfa6c44fade1e82b2f13fcd568062da85c760050ec0648ad89fd4dce5f"
    hermes_agent     = "docker.io/nousresearch/hermes-agent:v2026.6.5@sha256:9ad3b04ec916ea2c2da22358fd43b024c788d74073210695af88bfc2e63869b4"
    juicefs          = "reg.cluster.internal/randomcoww/juicefs:v1.3.1.1780981161@sha256:fc723719ed3542af488ac0db3da820a1a2e6386b549a4ba4978dffbae443e930"

    # models (model_file)
    "v5-small-text-matching-Q8_0.gguf"                                = "reg.cluster.internal/randomcoww/jina-embeddings-v5-text-small-text-matching-q8-0:v1773615151@sha256:ead9710eb051ea3b6ee32cebc1d1a8ba782c9e589ea972b48b15c173e169c4ee"
    "jina-reranker-v3-Q8_0.gguf"                                      = "reg.cluster.internal/randomcoww/jina-reranker-v3-q8-0:v1773185353@sha256:f9f985cd629f0a3f39d07de317545bb733ca14148f31040d567d267a8364ab4f"
    "NVIDIA-Nemotron-3-Super-120B-A12B-MXFP4_MOE-00001-of-00003.gguf" = "reg.cluster.internal/randomcoww/nvidia-nemotron-3-super-120b-a12b-mxfp4-moe:v1773610375@sha256:7c5065d9e53b4752fd40b496cd287946f5f5e5308ad29bfdea81c0622de6da0f"
    "NVIDIA-Nemotron-3-Nano-Omni-30B-A3B-Reasoning-UD-Q8_K_XL.gguf"   = "reg.cluster.internal/randomcoww/nvidia-nemotron-3-nano-omni-30b-a3b-reasoning-ud-q8-k-xl:v1777546075@sha256:44827b5c42b7bccbf22fb4dc4de0c2b3880cadd8f354dbd4a1a21c90de7389a3"
    "mmproj-F16.gguf"                                                 = "reg.cluster.internal/randomcoww/nvidia-nemotron-3-nano-omni-30b-a3b-reasoning-ud-q8-k-xl:v1777546075@sha256:44827b5c42b7bccbf22fb4dc4de0c2b3880cadd8f354dbd4a1a21c90de7389a3"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      default = "44.20260606.20.1.1780758983" # renovate: datasource=github-tags depName=randomcoww/fedora-coreos-config-custom
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
      mcp_proxy = {
        name = "mcp"
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
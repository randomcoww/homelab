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
      mtu     = 1500
    }
    # Kubernetes service external IP and LB
    service = {
      network = "192.168.208.0"
      cidr    = 24
      vlan_id = 80
      mtu     = 1500
      netnums = {
        apiserver    = 2
        external_dns = 31
        minio        = 34
        registry     = 35 # used by hosts without access to cluster DNS
        gateway_api  = 36
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
    }
    # Etcd peering
    etcd = {
      network = "192.168.228.0"
      cidr    = 26
      vlan_id = 70
      mtu     = 1500
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
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.5.28@sha256:e7291e59be84f8b2ac2be25604922b01c7cbc6b474b5f26e15c48dfb777997f8"
    # tier 1
    kube_proxy         = "registry.k8s.io/kube-proxy:v1.35.2@sha256:015265214cc874b593a7adccdcfe4ac15d2b8e9ae89881bdcd5bcb99d42e1862"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.20.0@sha256:ddc7f4212ed09a21024deb1f470a05240837712e74e4b9f6d1f2632ff10672e7"
    flannel            = "ghcr.io/flannel-io/flannel:v0.28.1@sha256:6a9c170acece4457ccb9cdfe53c787cc451e87990e20451bf20070b8895fa538"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:v1.9.0-flannel1@sha256:c6a08fe5bcb23b19c2fc7c1e47b95a967cc924224ebedf94e8623f27b6c258fa"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.1.0@sha256:c12498086c5ef3cb121c5b7f9aa755c14bd938ed4f6303da739eb0a0e9ca3410"
    minio              = "cgr.dev/chainguard/minio:latest@sha256:44cf8da6814e92d4e95f73c243ce462b27f546aa8ef3243fcd19759faab1b53f"
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.29.5-alpine@sha256:ccbac1a4c20a8b41c5dd1691bd91d63eda3b7989d643a33fd47841838519bfb9"
    # tier 2
    kea                   = "reg.cluster.internal/randomcoww/kea:v3.1.6.1773672731@sha256:f0087ea5643b1e146894a97467a21705985b53516e5764cfae5d3edd70ea2bd0"
    ipxe                  = "reg.cluster.internal/randomcoww/ipxe:v2.0.0.1773673098@sha256:916e86c3413f1c2152593b84bc015dcf73f43a59d02691b4046a7df7633f80e2"
    registry              = "ghcr.io/distribution/distribution:3.0.0@sha256:4ba3adf47f5c866e9a29288c758c5328ef03396cb8f5f6454463655fa8bc83e2"
    device_plugin         = "ghcr.io/squat/generic-device-plugin:latest@sha256:6a58b2896918e1a4a587d9b39bceec43b3f2e7c85aabdd39f8041add8a7a8585"
    github_actions_runner = "ghcr.io/actions/actions-runner:2.332.0@sha256:8c3f5970b8ceb90cbd3e89b80c6806bb74d9c31686e9177c743323a4539d12f5"
    # tier 3
    mountpoint       = "reg.cluster.internal/randomcoww/mountpoint-s3:v1.22.1.1773673748@sha256:5514c2b40be9420afbb915a9d487801f7c307689870c05fff42e16e6769d1486"
    hostapd          = "reg.cluster.internal/randomcoww/hostapd:v2.11.1773672764@sha256:1fd1b22baf1fc1a9a2cd160a0c1e19c2fbb4b95ae5aca049de7579411f39ae85"
    tailscale        = "ghcr.io/tailscale/tailscale:v1.94.2@sha256:95e528798bebe75f39b10e74e7051cf51188ee615934f232ba7ad06a3390ffa1"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v1773092553@sha256:eecee8dbca0deeecb38bca78ebeffd9cf8edcb7137fabc848db4fcad8652fd9c"
    llama_cpp_vulkan = "ghcr.io/mostlygeek/llama-swap:vulkan@sha256:fb63e76d984c6af6a0db99ffe010620af17b5a0ac35bbf2082f7d0f58d52c6e6"
    llama_cpp_rocm   = "ghcr.io/mostlygeek/llama-swap:rocm@sha256:19aa9d74557535ddd4b27687dbdf4faa300b74a9ed9f58e99bed07295b01cf7a"
    litestream       = "docker.io/litestream/litestream:0.5.9@sha256:58e338ede90c193d5f880348170cd6d80164bbc35220906a3c360271e7317f71"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:174f6a8498d88d2d98c265a952c2d552859bf315cd505746d1c0d4fbec37952f"
    open_webui       = "ghcr.io/open-webui/open-webui:v0.8.10@sha256:ee057955040ce91e3e787e4b7978c9c23e828972c68d01d787ed40f9a307df9f"
    kavita           = "ghcr.io/kareadita/kavita:0.8.9@sha256:1f2acae7466d022f037ea09f7989eb7c487f916b881174c7a6de33dbfa8acb39"
    lldap            = "ghcr.io/lldap/lldap:latest-alpine@sha256:af6daf88e67b2c6885d2426f711cb241751b515cc36a995d36ba77f2ffd199fb"
    authelia         = "ghcr.io/authelia/authelia:4.39.16@sha256:edbce01c5125249e4f4faea01e0f76f0031d64b4a1d0c2514a0ca69cb126d05f"
    cloudflared      = "docker.io/cloudflare/cloudflared:2026.3.0@sha256:6b599ca3e974349ead3286d178da61d291961182ec3fe9c505e1dd02c8ac31b0"
    rclone           = "ghcr.io/rclone/rclone:1.73.2@sha256:8a17d9b5cd5ce71bbb42e49e92ee83575d7fb03f6233d949d328e9d029b9376d"
    sunshine_desktop = "reg.cluster.internal/randomcoww/sunshine-desktop:v2026.314.174349.1773673086@sha256:cc14d211dff915b473eb911612b68ccded9698b212f730dc9897d608e48d9211"
    kubernetes_mcp   = "ghcr.io/containers/kubernetes-mcp-server:latest@sha256:f5e6d8f01bf71a2186e9c8209044e51bdaa8d1e75315813f15c80c714acc02fb"

    # models (model_file)
    "v5-small-text-matching-Q8_0.gguf"                                = "reg.cluster.internal/randomcoww/jina-embeddings-v5-text-small-text-matching-q8-0:v1773615151@sha256:ead9710eb051ea3b6ee32cebc1d1a8ba782c9e589ea972b48b15c173e169c4ee"
    "jina-reranker-v3-Q8_0.gguf"                                      = "reg.cluster.internal/randomcoww/jina-reranker-v3-q8-0:v1773185353@sha256:f9f985cd629f0a3f39d07de317545bb733ca14148f31040d567d267a8364ab4f"
    "NVIDIA-Nemotron-3-Super-120B-A12B-MXFP4_MOE-00001-of-00003.gguf" = "reg.cluster.internal/randomcoww/nvidia-nemotron-3-super-120b-a12b-mxfp4-moe:v1773610375@sha256:7c5065d9e53b4752fd40b496cd287946f5f5e5308ad29bfdea81c0622de6da0f"
    "GLM-4.7-Flash-Q8_0.gguf"                                         = "reg.cluster.internal/randomcoww/glm-4.7-flash-q8-0:v1773627383@sha256:1b2e6d762b1c003cbf5a2b79ea3a15fd309d436fdcb9229d3819a39366cb8645"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      default = "43.20260316.05" # renovate: datasource=github-tags depName=randomcoww/fedora-coreos-config-custom
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
      kubernetes_mcp = {
        name = "kubernetes-mcp"
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
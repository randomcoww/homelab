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
  container_image_regex = "(?<depName>(?<repository>[a-z0-9.-]+(?::\\d+|)(?:/[a-z0-9-]+|)+)/(?<image>[a-z0-9-]+)):(?<tag>(?<currentValue>(?<version>[\\w.]+)(?:-(?<compat>[\\w.-]+))?)(?:@(?<currentDigest>sha256:[a-f0-9]+))?)"

  # these fields are updated by renovate - don't use var substitutions
  container_images = {
    # static pod
    kube_apiserver          = "registry.k8s.io/kube-apiserver:v1.35.0@sha256:32f98b308862e1cf98c900927d84630fb86a836a480f02752a779eb85c1489f3"
    kube_controller_manager = "registry.k8s.io/kube-controller-manager:v1.35.0@sha256:3e343fd915d2e214b9a68c045b94017832927edb89aafa471324f8d05a191111"
    kube_scheduler          = "registry.k8s.io/kube-scheduler:v1.35.0@sha256:0ab622491a82532e01876d55e365c08c5bac01bcd5444a8ed58c1127ab47819f"
    etcd                    = "registry.k8s.io/etcd:v3.6.7@sha256:70cd5d29d2efcbc4c15f2a63183fd537aae77ddbc46b3b97a8a97bc8751ec3b4"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.5.21@sha256:e3401048a8dfa3bd12210b5a1b56d1d53513170e20c1ed0a93a67d49500129e6"
    # tier 1
    kube_proxy         = "registry.k8s.io/kube-proxy:v1.35.0@sha256:c818ca1eff765e35348b77e484da915175cdf483f298e1f9885ed706fcbcb34c"
    flannel            = "ghcr.io/flannel-io/flannel:v0.28.0@sha256:adecdcb715b153ef4fadda24142f85556818b6b75170a9dae83ff82995183c86"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:latest@sha256:c6a08fe5bcb23b19c2fc7c1e47b95a967cc924224ebedf94e8623f27b6c258fa"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.0.3@sha256:4e2791cc0238ae01b3986d827f4d568a25d846c94bab51238fe6241281a27113"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.20.0@sha256:ddc7f4212ed09a21024deb1f470a05240837712e74e4b9f6d1f2632ff10672e7"
    minio              = "ghcr.io/randomcoww/minio:v20251015.172955@sha256:2e53a52a621b158089331912855c332a89a57ad96bf010361ef2e71a0a5f50cd"
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.29.3-alpine@sha256:062042031264627f065dbe8e16a2b54ec9a12757843c2d956e65623e650a1142"
    # tier 2
    kea                   = "ghcr.io/randomcoww/kea:v3.1.4@sha256:f380a5ca82a734686abef60d4aa583a9374d7e985dd4aca4e77b1bde692a1780"
    stork_agent           = "ghcr.io/randomcoww/stork-agent:v2.3.2@sha256:3fd0b7caf76b3d4001531d91341d4e980819da331a94eff9bf320547884d56d2"
    ipxe                  = "ghcr.io/randomcoww/ipxe:v20251229.142018@sha256:aa94d7236b073207f427a6f6678cbb66d4bedc4e1581429792478e45ce5b51ab"
    registry              = "ghcr.io/distribution/distribution:3.0.0@sha256:4ba3adf47f5c866e9a29288c758c5328ef03396cb8f5f6454463655fa8bc83e2"
    device_plugin         = "ghcr.io/squat/generic-device-plugin:latest@sha256:8e74085edef446b02116d0e851a7a5576b4681e07fe5be75c4e5f6791a8ad0f7"
    github_actions_runner = "ghcr.io/actions/actions-runner:2.331.0@sha256:dced476aa42703ebd9aafc295ce52f160989c4528e831fc3be2aef83a1b3f6da"
    # tier 3
    mountpoint       = "reg.cluster.internal/randomcoww/mountpoint-s3:v1.21.0@sha256:3469956d5b1fb9af06f8d9c32c4a348557e910c7664f7ab3cf69f31fdac64044"
    hostapd          = "reg.cluster.internal/randomcoww/hostapd-noscan:v20251229.230418@sha256:7739c3f446e5ae326e82eedfdcd418e1e533c0e9a770b9520507866e89745147"
    tailscale        = "ghcr.io/tailscale/tailscale:v1.92.5@sha256:4a0aaacee6f28e724c1f80c986e5776c9c979d8f7e19274c2cae2d495cc8d625"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v20251229.141928@sha256:e3ac16365490e8e1fefc224d1ec59445a6de852d567a2401dbab8a5516115d14"
    llama_cpp        = "ghcr.io/mostlygeek/llama-swap:vulkan-non-root@sha256:a4b03f8779ac1feae68c167ea19cf6d60eb9ce5ff94c7a9ac0877cc80718734b"
    sunshine_desktop = "reg.cluster.internal/randomcoww/sunshine-desktop:v2026.118.33530@sha256:e9dda1eea03713ca5a5bf0aeb342069ac559b58ff0547df753af56c538cdb663"
    litestream       = "docker.io/litestream/litestream:0.5.6@sha256:871d0c5f28b52b0a0a29614728d6e9e5cbdaaab36d8af177010de2c63d9da9a5"
    valkey           = "ghcr.io/valkey-io/valkey:9.0.1-alpine@sha256:c106a0c03bcb23cbdf9febe693114cb7800646b11ca8b303aee7409de005faa8"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:d6c00e1d34c199a7ca141f7a6b0b9ddb850d931ff06d4cd0ffb53ef02c05b666"
    open_webui       = "ghcr.io/open-webui/open-webui:0.7.2@sha256:16d9a3615b45f14a0c89f7ad7a3bf151f923ed32c2e68f9204eb17d1ce40774b"
    kavita           = "ghcr.io/kareadita/kavita:0.8.9@sha256:1f2acae7466d022f037ea09f7989eb7c487f916b881174c7a6de33dbfa8acb39"
    navidrome        = "ghcr.io/navidrome/navidrome:0.59.0@sha256:4edc8a1de3e042f30b78a478325839f4395177eb8201c27543dccc0eba674f23"
    lldap            = "ghcr.io/lldap/lldap:latest-alpine@sha256:fdc970c3a97c0aae7d9e27aac5ddfe9cedb98b27a7da1bb19517d1fe8af94553"
    authelia         = "ghcr.io/authelia/authelia:4.39.15@sha256:d23ee3c721d465b4749cc58541cda4aebe5aa6f19d7b5ce0afebb44ebee69591"
    cloudflared      = "docker.io/cloudflare/cloudflared:2026.1.1@sha256:5bb6a0870686742d00e171f36c892ba91e5994631bc363d808b9ba822262dad6"
    playwright       = "reg.cluster.internal/randomcoww/patchright-server:v1.57.0@sha256:6fca26aa3e7b0bff0be945c11d8111b80fe02e9b639e49f610774e4907f76006"
    mcp_oauth_proxy  = "reg.cluster.internal/randomcoww/mcp-auth-proxy:v2.5.3@sha256:40c8f6413b7adfc2e0dff85700fc5d6de041d5e6256e66129101462e4a5c58dd"
    prometheus_mcp   = "ghcr.io/pab1it0/prometheus-mcp-server:1.5.3@sha256:32d47c88845ee78bc343d4c3a39a24b1bd9bebce4f53becdbbf5704221185925"
    kubernetes_mcp   = "reg.cluster.internal/randomcoww/kubernetes-mcp-server:main@sha256:440a0ede9dcb0a1ebe90aab4f73e8bad037a44a94c42a4d97c616b6b15ce5436"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      default = "fedora-coreos-43.20260124.22" # renovate: randomcoww/fedora-coreos-config-custom
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
    kube_proxy_metrics = 50255
    etcd_client        = 58082
    etcd_client_proxy  = 58085 # only listens on localhost
    etcd_peer          = 58083
    etcd_metrics       = 58086
    flannel_healthz    = 58084
    bgp                = 179 # not configurable
    kube_vip_metrics   = 58089
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
      }
      qrcode_hostapd = {
        name    = "qrcode-hostapd"
        ingress = "hostapd.${local.domains.public}"
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
        service = "sunshine.${local.domains.public}"
        ingress = "sunadmin.${local.domains.public}"
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
      kubernetes_mcp = {
        name      = "kubernetes-mcp"
        namespace = "kube-system"
        ingress   = "kubernetes-mcp.${local.domains.public}"
      }
      prometheus_mcp = {
        name      = "prometheus-mcp"
        namespace = "monitoring"
        ingress   = "prometheus-mcp.${local.domains.public}"
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
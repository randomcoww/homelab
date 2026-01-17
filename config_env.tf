locals {
  timezone       = "America/Los_Angeles"
  butane_version = "1.5.0"
  default_mtu    = 1500 # work around r8169 transmit queue 0 timed out

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
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.5.20@sha256:b89224fc8bbb3824a4857af25dd4d6aa068caa1c2c6cd819965285d29a935405"
    # tier 1
    kube_proxy         = "registry.k8s.io/kube-proxy:v1.35.0@sha256:c818ca1eff765e35348b77e484da915175cdf483f298e1f9885ed706fcbcb34c"
    flannel            = "ghcr.io/flannel-io/flannel:v0.28.0@sha256:adecdcb715b153ef4fadda24142f85556818b6b75170a9dae83ff82995183c86"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:latest@sha256:c6a08fe5bcb23b19c2fc7c1e47b95a967cc924224ebedf94e8623f27b6c258fa"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.0.3@sha256:4e2791cc0238ae01b3986d827f4d568a25d846c94bab51238fe6241281a27113"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.20.0@sha256:ddc7f4212ed09a21024deb1f470a05240837712e74e4b9f6d1f2632ff10672e7"
    minio              = "ghcr.io/randomcoww/minio:v20251015.172955@sha256:20f5e402f0de6f262465635ae8d5bf097bf3558b7487737852d4aca2ccfc7b8d"
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.29.3-alpine@sha256:7445ca31ca290543d404a36051a0dfe5575913381d5646e62b9ac4c3f8afef8f"
    # tier 2
    kea                   = "ghcr.io/randomcoww/kea:v3.1.4@sha256:a3cb12232c39b8a31a4702379c7a8e82136f8a33ff4f9e8d34c7d878e6988c5e"
    stork_agent           = "ghcr.io/randomcoww/stork-agent:v2.3.2@sha256:507658a323a8d1b7b0fa20bb07357ac40af5c41212859a7ad9dc808dd759a3a1"
    ipxe                  = "ghcr.io/randomcoww/ipxe:v20251229.142018@sha256:aa94d7236b073207f427a6f6678cbb66d4bedc4e1581429792478e45ce5b51ab"
    registry              = "ghcr.io/distribution/distribution:3.0.0@sha256:4ba3adf47f5c866e9a29288c758c5328ef03396cb8f5f6454463655fa8bc83e2"
    device_plugin         = "ghcr.io/squat/generic-device-plugin:latest@sha256:8e74085edef446b02116d0e851a7a5576b4681e07fe5be75c4e5f6791a8ad0f7"
    github_actions_runner = "ghcr.io/actions/actions-runner:2.331.0@sha256:dced476aa42703ebd9aafc295ce52f160989c4528e831fc3be2aef83a1b3f6da"
    # tier 3
    mountpoint       = "reg.cluster.internal/randomcoww/mountpoint-s3:v1.21.0@sha256:cfc30c44bccfb973d2eedaa0d844cf43a8fabcf3a0c34718c9caf8f0ad036d68"
    hostapd          = "reg.cluster.internal/randomcoww/hostapd-noscan:v20251229.230418@sha256:7739c3f446e5ae326e82eedfdcd418e1e533c0e9a770b9520507866e89745147"
    tailscale        = "ghcr.io/tailscale/tailscale:v1.92.5@sha256:4a0aaacee6f28e724c1f80c986e5776c9c979d8f7e19274c2cae2d495cc8d625"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v20251229.141928@sha256:e3ac16365490e8e1fefc224d1ec59445a6de852d567a2401dbab8a5516115d14"
    llama_cpp        = "ghcr.io/mostlygeek/llama-swap:vulkan-non-root@sha256:19bbea210bc06793b93797fc06598bf5113b0f5ae5f2c7e204a79880bd82b9ab"
    sunshine_desktop = "reg.cluster.internal/randomcoww/sunshine-desktop:v2026.105.231052@sha256:f9b877e777a9941c6802ea89b49d793c1a42a21477b5868a8208b314be027c99"
    litestream       = "docker.io/litestream/litestream:0.5.2@sha256:e4fd484cb1cd9d6fa58fff7127d551118e150ab75b389cf868a053152ba6c9c0"
    valkey           = "ghcr.io/valkey-io/valkey:9.0.1-alpine@sha256:c106a0c03bcb23cbdf9febe693114cb7800646b11ca8b303aee7409de005faa8"
    mcp_proxy        = "ghcr.io/tbxark/mcp-proxy:v0.43.2@sha256:70c0e02d39c4c0898e610b3a30954f7930628fa6f4fb447bad14c32382a25879"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:bc805054d5801d18b9750852e075e599e543eddc2d7962918f0722244d40ea09"
    open_webui       = "ghcr.io/open-webui/open-webui:0.7.2@sha256:16d9a3615b45f14a0c89f7ad7a3bf151f923ed32c2e68f9204eb17d1ce40774b"
    kavita           = "ghcr.io/kareadita/kavita:0.8.9@sha256:69e9117b9b681849a6f6d5dc8411bfa6a326ed77f78cc49d9cbce49584ff6c0d"
    lldap            = "ghcr.io/lldap/lldap:latest-alpine@sha256:898f91b2042ab23659954588999eb38bb4d556c340318c76012000fa4f4b56ef"
    authelia         = "ghcr.io/authelia/authelia:4.39.15@sha256:d23ee3c721d465b4749cc58541cda4aebe5aa6f19d7b5ce0afebb44ebee69591"
    cloudflared      = "docker.io/cloudflare/cloudflared:2025.11.1@sha256:89ee50efb1e9cb2ae30281a8a404fed95eb8f02f0a972617526f8c5b417acae2"
    playwright       = "reg.cluster.internal/randomcoww/patchright-server:v1.57.0@sha256:cf5190020ef47a4a4384b23b638b2afe3c00d70785dbda038b35e2d20b344c68"
    prometheus_mcp   = "ghcr.io/pab1it0/prometheus-mcp-server:1.5.2@sha256:4cad9af3814dba1d128b126f7393b98c4f98a183c12352fc6d6210da3410a96e"
    kubernetes_mcp   = "reg.cluster.internal/randomcoww/kubernetes-mcp-server:main@sha256:ec037fdc591af2e2f8d7655a8d05237da07100201b944ea54458bdb53f3489b4"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      default = "fedora-coreos-43.20260112.04" # renovate: randomcoww/fedora-coreos-config-custom
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
      kubernetes_mcp = {
        name      = "kubernetes-mcp"
        namespace = "kube-system"
        ingress   = "kubernetes-mcp.${local.domains.kubernetes}"
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
      prometheus_mcp = {
        name      = "prometheus-mcp"
        namespace = "monitoring"
        ingress   = "prometheus-mcp.${local.domains.kubernetes}"
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
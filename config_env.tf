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
      mtu            = local.default_mtu
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

  container_image_regex = "(?<depName>(?<repository>[a-z0-9.-]+(?::\\d+|)(?:/[a-z0-9-]+|)+)/(?<image>[a-z0-9-]+)):(?<tag>(?<currentValue>(?<version>[\\w.]+)(?:-(?<compat>[\\w.-]+))?)(?:@(?<currentDigest>sha256:[a-f0-9]+))?)" # compatible with renovate

  # these fields are updated by renovate - don't use var substitutions
  container_images = {
    # static pod
    kube_apiserver          = "registry.k8s.io/kube-apiserver:v1.34.2@sha256:e009ef63deaf797763b5bd423d04a099a2fe414a081bf7d216b43bc9e76b9077"
    kube_controller_manager = "registry.k8s.io/kube-controller-manager:v1.34.2@sha256:5c3998664b77441c09a4604f1361b230e63f7a6f299fc02fc1ebd1a12c38e3eb"
    kube_scheduler          = "registry.k8s.io/kube-scheduler:v1.34.2@sha256:44229946c0966b07d5c0791681d803e77258949985e49b4ab0fbdff99d2a48c6"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.4.8@sha256:41ff93b85c5ae1aeca9af49fdfad54df02ecd4604331f6763a31bdaf73501464"
    etcd                    = "gcr.io/etcd-development/etcd:v3.6.6@sha256:60a30b5d81b2217555e2cfb9537f655b7ba97220b99c39ee2e162a7127225890"
    # tier 1
    kube_proxy         = "registry.k8s.io/kube-proxy:v1.34.2@sha256:d8b843ac8a5e861238df24a4db8c2ddced89948633400c4660464472045276f5"
    flannel            = "ghcr.io/flannel-io/flannel:v0.27.4@sha256:2ff3c5cb44d0e27b09f27816372084c98fa12486518ca95cb4a970f4a1a464c4"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:latest@sha256:20bcb9ad81033d9b22378f7834800437bc77ffa92509d78830d0008a29f430d5"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.0.1@sha256:554d1e07ee24a046bbc7fba67f438c01b480b072c6f0b99215321fc0eb440178"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.19.0@sha256:f76114338104264f655b23138444481b20bb9d6125742c7240fac25936fe164e"
    minio              = "ghcr.io/randomcoww/minio:RELEASE.2025-10-15T17-29-55Z.20251021.2244@sha256:21f046fd3848b8c2539c3aae29a3bd6921438c97a320955dafa41820169e7364"
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.29.2-alpine@sha256:b7d6477d6b83b6c152ffb766318f1f103553174ef91b195c3dfcb9a00e1e933d"
    # tier 2
    kea                   = "ghcr.io/randomcoww/kea:v3.1.3.20251110.1410@sha256:b910e5ef007cbb8cfc1fb5a669e7010fb95fa05251f01f10bdd76dd3d439d625"
    stork_agent           = "ghcr.io/randomcoww/stork-agent:v2.3.1.20251110.1419@sha256:1b774eb0cb5bb168be37b257a5a6ada58bd70bc5b3e17ee99940a0fda05eb984"
    ipxe                  = "ghcr.io/randomcoww/ipxe:v1.20251110.1419@sha256:34d6d07967bde845d132f8968659681e606ddfde0a9c73213c39a364869d5fc8"
    registry              = "ghcr.io/distribution/distribution:3.0.0@sha256:4ba3adf47f5c866e9a29288c758c5328ef03396cb8f5f6454463655fa8bc83e2"
    device_plugin         = "ghcr.io/squat/generic-device-plugin:latest@sha256:e812d2d79e5642bf89e87203d422d351d3fcbbd29ef440481eb7638651d3eb6e"
    github_actions_runner = "ghcr.io/actions/actions-runner:2.329.0@sha256:75599cd393958a52142f489a160123f5b9b21605a40609696deb13d49867d53f"
    # tier 3
    mountpoint       = "reg.cluster.internal/randomcoww/mountpoint-s3:v1.21.0.20251110.1426@sha256:ef77a421300d39e23839e67fc7cb8b3b277c0e82d4a65bb412bd06e74632a1b1"
    hostapd          = "reg.cluster.internal/randomcoww/hostapd-noscan:v1.20251110.1425@sha256:bc112f81f0136a661bd6c4b1f300c6fcc7d47d4c5717cbdd26f6722805cf74da"
    tailscale        = "ghcr.io/tailscale/tailscale:v1.90.6@sha256:8eb8b450a85856807e8a216c4697333e15f8701cb6d344bed851bf6aa6a9605c"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v1.20251110.1417@sha256:24c085be4b09e1c7a2149042d88b20f0e266d63453b48fb4a0561fa3c3e2007f"
    llama_cpp        = "ghcr.io/mostlygeek/llama-swap:cuda@sha256:6916399901a7897656a0b1c9386b376f53bd8ac197bfef81753b407b8656c8fc"
    sunshine_desktop = "reg.cluster.internal/randomcoww/sunshine-desktop:v2025.1027.181930.20251110.1425@sha256:df9187c4b4a32306349a565f5cbed25fa15a0b92f02d062a4ad81de988df1393"
    litestream       = "docker.io/litestream/litestream:0.5.2@sha256:e4fd484cb1cd9d6fa58fff7127d551118e150ab75b389cf868a053152ba6c9c0"
    valkey           = "ghcr.io/valkey-io/valkey:9.0.0-alpine@sha256:b4ee67d73e00393e712accc72cfd7003b87d0fcd63f0eba798b23251bfc9c394"
    nvidia_driver    = "reg.cluster.internal/randomcoww/nvidia-driver-container:v580.105.08.20251105.1811-fedora43@sha256:45aa19ddd0fb4adb374bd2cbb49f1212177cbb22ff125729148b2a82bda849c5"
    mcp_proxy        = "ghcr.io/tbxark/mcp-proxy:v0.43.0@sha256:0ab33e72c494ee795e9b95922beab736f251514d9e6ec1dcbe6ca317749ba5d3"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:d477c0460cc06afa57541f24c7adcae3846303a125c3ae785b9893c9c2c2186f"
    open_webui       = "ghcr.io/open-webui/open-webui:v0.6.36@sha256:dfe43b30a5474164b1a81e1cce298a6769bb22144f74df556beefee4ccca5394"
    kavita           = "ghcr.io/kareadita/kavita:0.8.8@sha256:22c42f3cc83fb98b98a6d6336200b615faf2cfd2db22dab363136744efda1bb0"
    lldap            = "ghcr.io/lldap/lldap:latest-alpine@sha256:36482c2bf004d9ce1c67d95a7ef1788515f35707930294a477a814bcb2acc969"
    authelia         = "ghcr.io/authelia/authelia:4.39.14@sha256:88f1494b6ac1174641770f106335ab67752d66e5822b4059badca220b5d6153b"
    cloudflared      = "docker.io/cloudflare/cloudflared:2025.11.1@sha256:89ee50efb1e9cb2ae30281a8a404fed95eb8f02f0a972617526f8c5b417acae2"
    rclone           = "ghcr.io/rclone/rclone:1.71.2@sha256:3103526c506266a9ecdf064efe99bf3677d92ef6407af124d8c56b4f49cbaa51"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      coreos = "fedora-coreos-43.20251107.08" # renovate: randomcoww/fedora-coreos-config-custom
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
    etcd_client        = 58082
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
    cni_bridge_interface_name = "cni0"
    kubelet_client_user       = "kube-apiserver-kubelet-client"
    helm_release_timeout      = 600

    cert_issuers = {
      acme_prod    = "letsencrypt-prod"
      acme_staging = "letsencrypt-staging"
      ca_internal  = "internal"
    }
    ca_bundle_configmap = "ca-trust-bundle.crt"

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
      webdav_ebooks = {
        name    = "webdav-ebooks"
        ingress = "ebooks.${local.domains.public}"
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
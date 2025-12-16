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
    kube_apiserver          = "registry.k8s.io/kube-apiserver:v1.34.3@sha256:5af1030676ceca025742ef5e73a504d11b59be0e5551cdb8c9cf0d3c1231b460"
    kube_controller_manager = "registry.k8s.io/kube-controller-manager:v1.34.3@sha256:716a210d31ee5e27053ea0e1a3a3deb4910791a85ba4b1120410b5a4cbcf1954"
    kube_scheduler          = "registry.k8s.io/kube-scheduler:v1.34.3@sha256:f9a9bc7948fd804ef02255fe82ac2e85d2a66534bae2fe1348c14849260a1fe2"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.4.8@sha256:41ff93b85c5ae1aeca9af49fdfad54df02ecd4604331f6763a31bdaf73501464"
    etcd                    = "gcr.io/etcd-development/etcd:v3.6.6@sha256:60a30b5d81b2217555e2cfb9537f655b7ba97220b99c39ee2e162a7127225890"
    # tier 1
    kube_proxy         = "registry.k8s.io/kube-proxy:v1.34.3@sha256:7298ab89a103523d02ff4f49bedf9359710af61df92efdc07bac873064f03ed6"
    flannel            = "ghcr.io/flannel-io/flannel:v0.27.4@sha256:2ff3c5cb44d0e27b09f27816372084c98fa12486518ca95cb4a970f4a1a464c4"
    flannel_cni_plugin = "ghcr.io/flannel-io/flannel-cni-plugin:latest@sha256:c6a08fe5bcb23b19c2fc7c1e47b95a967cc924224ebedf94e8623f27b6c258fa"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v1.0.2@sha256:ee3702abc2daeb93399c22b14aa61aa233013f2a610e64ff3864033ebb3fedbc"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.20.0@sha256:ddc7f4212ed09a21024deb1f470a05240837712e74e4b9f6d1f2632ff10672e7"
    minio              = "ghcr.io/randomcoww/minio:v20251015.172955@sha256:01701b75c709dea9f40ca9181bbb6d32aee9e2e04c28c121b901ed9e7ea3edd0"
    nginx              = "docker.io/nginxinc/nginx-unprivileged:1.29.3-alpine@sha256:11cab1801e5b195e6e6aab60b4dce008081bb096ab919233b75265b6b3d8ea47"
    # tier 2
    kea                   = "ghcr.io/randomcoww/kea:v3.1.4@sha256:4e39daed40e1f040b1de83592cb11bc8f71e06327313c2ddaef0dcbd979f4ede"
    stork_agent           = "ghcr.io/randomcoww/stork-agent:v2.3.2@sha256:cba5d29063219decf1af5d65b30747370e97d8ae417d5c3caa8d1c269cf58cdd"
    ipxe                  = "ghcr.io/randomcoww/ipxe:v20251215.142351@sha256:33e8d4e3302fc8b94f1433e023c09ff347adb629721b472153c989a4a3454ef3"
    registry              = "ghcr.io/distribution/distribution:3.0.0@sha256:4ba3adf47f5c866e9a29288c758c5328ef03396cb8f5f6454463655fa8bc83e2"
    device_plugin         = "ghcr.io/squat/generic-device-plugin:latest@sha256:29a59a330b93ed4173109839329796a39c528d0d0afeee76291b33787ae19001"
    github_actions_runner = "ghcr.io/actions/actions-runner:2.330.0@sha256:ee54ad8776606f29434f159196529b7b9c83c0cb9195c1ff5a7817e7e570dcfe"
    # tier 3
    mountpoint       = "reg.cluster.internal/randomcoww/mountpoint-s3:v1.21.0@sha256:77644dfd56c0e8cb588dc5258e44bec1d1d1fcf1615161973b9bd254260e13b5"
    hostapd          = "reg.cluster.internal/randomcoww/hostapd-noscan:v20251215.143221@sha256:d4b9fd4e9b234da95eed59aa3725e4cd02044f5f702a854ab4ff3c2a65b1b167"
    tailscale        = "ghcr.io/tailscale/tailscale:v1.90.9@sha256:9975353aae933e8fbd1a81226d092a9225b9a0f98b173d365a9d525eca1cc298"
    qrcode_generator = "reg.cluster.internal/randomcoww/qrcode-resource:v20251215.142240@sha256:c4052eb7d6e638f0fa404a833552869b25273ee64f713a601c0c9556908093ce"
    llama_cpp        = "ghcr.io/mostlygeek/llama-swap:cuda@sha256:e4ecbab8fdec6530bd0ae07ce62f7a5eaf2bc20e928ef4c316275e9f8d039d4e"
    sunshine_desktop = "reg.cluster.internal/randomcoww/sunshine-desktop:v2025.1210.519@sha256:16742039f364356a23745802f109708a0178682cabfd9d2dcd44d8670b1cd2b2"
    litestream       = "docker.io/litestream/litestream:0.5.3@sha256:b3d459d09d63df998d26bf32530ee020a6ab9a9151152cb57be3ee6e9dc45625"
    valkey           = "ghcr.io/valkey-io/valkey:9.0.1-alpine@sha256:1be494495248d53e3558b198a1c704e6b559d5e99fe4c926e14a8ad24d76c6fa"
    nvidia_driver    = "reg.cluster.internal/randomcoww/nvidia-driver-container:v580.105.08-fedora43@sha256:b84a1f8f2ae22727a66cdfe518279917fb1cf752474d89af7ca87992642a0fa4"
    mcp_proxy        = "ghcr.io/tbxark/mcp-proxy:v0.43.0@sha256:0ab33e72c494ee795e9b95922beab736f251514d9e6ec1dcbe6ca317749ba5d3"
    searxng          = "ghcr.io/searxng/searxng:latest@sha256:b88ef002ab1d9a901766f9eb59779089a74e8f444477e0151fa8cd1f91a02006"
    open_webui       = "ghcr.io/open-webui/open-webui:0.6.41@sha256:3e07bcede92e97cc3e741de095045a8b5d20bc257ecdb713bd2a47f68e9dff72"
    kavita           = "ghcr.io/kareadita/kavita:0.8.8@sha256:22c42f3cc83fb98b98a6d6336200b615faf2cfd2db22dab363136744efda1bb0"
    lldap            = "ghcr.io/lldap/lldap:latest-alpine@sha256:72f526a8df92e8457d44d9a625cfbe43273285776c979e7144a31b26ebe65d1a"
    authelia         = "ghcr.io/authelia/authelia:4.39.15@sha256:d23ee3c721d465b4749cc58541cda4aebe5aa6f19d7b5ce0afebb44ebee69591"
    cloudflared      = "docker.io/cloudflare/cloudflared:2025.11.1@sha256:89ee50efb1e9cb2ae30281a8a404fed95eb8f02f0a972617526f8c5b417acae2"
  }

  host_images = {
    for name, tag in {
      # these fields are updated by renovate - don't use var substitutions
      coreos = "fedora-coreos-43.20251201.07" # renovate: randomcoww/fedora-coreos-config-custom
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
locals {
  timezone       = "America/Los_Angeles"
  aws_region     = "us-west-2"
  butane_version = "1.5.0"

  # Setting to 9000 seems to reduce success rate of PXE boot
  default_mtu = 1500

  users = {
    ssh = {
      name     = "fcos"
      home_dir = "/var/tmp-home/fcos"
      groups = [
        "adm",
        "sudo",
        "systemd-journal",
        "wheel",
      ],
    }
    client = {
      name     = "randomcoww"
      home_dir = "/var/home/randomcoww"
      uid      = 10000
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
      enable_dns     = true
      enable_mdns    = true
      table_id       = 220
      table_priority = 32760
      netnums = {
        gateway = 2
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
        apiserver              = 2
        external_dns           = 31
        ingress_nginx          = 32
        ingress_nginx_external = 35
        matchbox               = 39
        matchbox_api           = 33
        minio                  = 34
        sunshine               = 36
        alpaca_db              = 38
        satisfactory_server    = 40
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
    # Main and mobile backup WAN
    wan = {
      vlan_id = 30
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

  container_images = {
    # Igntion
    kube_apiserver          = "ghcr.io/randomcoww/k8s-control-plane:v1.32.1"
    kube_controller_manager = "ghcr.io/randomcoww/k8s-control-plane:v1.32.1"
    kube_scheduler          = "ghcr.io/randomcoww/k8s-control-plane:v1.32.1"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.4.0"
    etcd                    = "gcr.io/etcd-development/etcd:v3.5.18"

    # Helm
    kea                = "ghcr.io/randomcoww/kea:v20250302.0329"
    matchbox           = "quay.io/poseidon/matchbox:v0.11.0"
    tftpd              = "ghcr.io/randomcoww/tftpd-ipxe:v20250210.0030"
    hostapd            = "ghcr.io/randomcoww/hostapd-noscan:v2.11"
    flannel            = "docker.io/flannel/flannel:v0.26.4"
    flannel_cni_plugin = "docker.io/flannel/flannel-cni-plugin:v1.6.2-flannel1"
    kapprover          = "ghcr.io/randomcoww/kapprover:v0.1.0"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.15.1"
    kube_proxy         = "ghcr.io/randomcoww/kube-proxy:v20250302.0254"
    litestream         = "docker.io/litestream/litestream:0.3.13"
    tailscale          = "ghcr.io/randomcoww/tailscale-nft:v20250302.0250"
    code_server        = "ghcr.io/randomcoww/code-server:v20250304.2000"
    lldap              = "ghcr.io/lldap/lldap:2025-02-05-alpine-rootless"
    keydb              = "docker.io/eqalpha/keydb:alpine_x86_64_v6.3.4"
    clickhouse         = "docker.io/clickhouse/clickhouse-server:25.1.7.20-alpine"
    qrcode_generator   = "ghcr.io/randomcoww/qrcode-generator:v20250210.0031"
    rclone             = "docker.io/rclone/rclone:1.69.1"
    s3fs               = "ghcr.io/randomcoww/s3fs:v20250302.0319"
    mountpoint         = "ghcr.io/randomcoww/mountpoint-s3:v20250302.0330"
    audioserve         = "docker.io/izderadicka/audioserve:latest"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v0.8.9"
    sunshine_desktop   = "ghcr.io/randomcoww/sunshine-desktop:v20250302.0327"
    nvidia_driver      = "ghcr.io/randomcoww/nvidia-driver-container:v570.86.15-fedora41"
    steamcmd           = "ghcr.io/randomcoww/steamcmd:v20250302.0425"
    kvm_device_plugin  = "ghcr.io/randomcoww/kvm-device-plugin:v20250211.0006"
    stork_agent        = "ghcr.io/randomcoww/stork-agent:v20250302.0320"
    vaultwarden        = "docker.io/vaultwarden/server:1.33.2-alpine"
    llama_cpp          = "ghcr.io/ggml-org/llama.cpp:server-cuda"
  }

  pxeboot_images = {
    coreos = "fedora-coreos-41.20250302.02" # randomcoww/fedora-coreos-config-custom
  }

  kubernetes = {
    cluster_name              = "prod-10"
    kubelet_root_path         = "/var/lib/kubelet"
    static_pod_manifest_path  = "/var/lib/kubelet/manifests"
    containers_path           = "/var/lib/containers"
    cni_bridge_interface_name = "cni0"

    cert_issuer_prod    = "letsencrypt-prod"
    cert_issuer_staging = "letsencrypt-staging"

    kubelet_client_user     = "kube-apiserver-kubelet-client"
    front_proxy_client_user = "front-proxy-client"
    node_bootstrap_user     = "system:node-bootstrapper"
  }

  ha = {
    keepalived_config_path = "/etc/keepalived/keepalived.conf.d"
    haproxy_config_path    = "/etc/haproxy/haproxy.cfg.d"
    bird_config_path       = "/etc/bird.conf.d"
    bird_cache_table_name  = "cache"
    bgp_as                 = 65005
  }

  domains = {
    mdns       = "local"
    public     = "fuzzybunny.win"
    kubernetes = "cluster.internal"
    tailscale  = "fawn-turtle.ts.net"
  }

  kubernetes_ingress_endpoints = {
    for k, domain in {
      auth                = "auth"
      vaultwarden         = "vw"
      code                = "code"
      alpaca_db           = "alpaca-db"
      lldap_http          = "ldap"
      qrcode              = "qrcode"
      qrcode_hostapd      = "wifi"
      webdav_pictures     = "pictures"
      webdav_videos       = "videos"
      sunshine            = "sunshine"
      sunshine_admin      = "sunadmin"
      audioserve          = "audioserve"
      satisfactory_server = "satisfactory"
      monitoring          = "m"
    } :
    k => "${domain}.${local.domains.public}"
  }

  ingress_classes = {
    ingress_nginx          = "ingress-nginx"
    ingress_nginx_external = "ingress-nginx-external"
  }

  kubernetes_services = {
    for name, e in {
      apiserver = {
        name      = "kubernetes"
        namespace = "default"
      }
      etcd = {
        name      = "etcd"
        namespace = "kube-system"
      }
      authelia = {
        name      = "authelia"
        namespace = "authelia"
      }
      authelia_redis = {
        name      = "authelia-redis"
        namespace = "authelia"
      }
      ingress_nginx = {
        name      = "${local.ingress_classes.ingress_nginx}-controller"
        namespace = "ingress-nginx"
      }
      ingress_nginx_external = {
        name      = "${local.ingress_classes.ingress_nginx_external}-controller"
        namespace = "ingress-nginx"
      }
      matchbox = {
        name      = "matchbox"
        namespace = "default"
      }
      minio = {
        name      = "minio"
        namespace = "minio"
      }
      lldap = {
        name      = "lldap"
        namespace = "lldap"
      }
      alpaca_db = {
        name      = "alpaca-db"
        namespace = "alpaca"
      }
      prometheus = {
        name      = "prometheus"
        namespace = "monitoring"
      }
      llama_cpp = {
        name      = "llama-cpp"
        namespace = "default"
      }
    } :
    name => merge(e, {
      endpoint = "${e.name}.${e.namespace}"
      fqdn     = "${e.name}.${e.namespace}.svc.${local.domains.kubernetes}"
    })
  }

  host_ports = {
    kea_peer           = 50060
    kea_metrics        = 58087
    tftpd              = 69
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
    code               = 58085
    bgp                = 179
  }

  service_ports = {
    matchbox     = 80
    matchbox_api = 50101
    minio        = 9000
    lldap        = 6360
    redis        = 6379
    clickhouse   = 9440
    metrics      = 9153
    prometheus   = 80
    llama_cpp    = 8080
  }

  minio = {
    data_buckets = {
      boot = {
        name = "data-boot"
        acl  = "public-read"
      }
      music = {
        name = "data-music"
      }
      pictures = {
        name = "data-pictures"
      }
      videos = {
        name = "data-videos"
      }
      models = {
        name = "data-models"
        acl  = "public-read"
      }
    }
  }

  upstream_dns = {
    ip       = "1.1.1.1"
    hostname = "one.one.one.one"
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

  pxeboot_image_set = {
    for type, tag in local.pxeboot_images :
    type => {
      kernel = "${tag}-live-kernel-x86_64"
      initrd = "${tag}-live-initramfs.x86_64.img"
      rootfs = "${tag}-live-rootfs.x86_64.img"
    }
  }
}

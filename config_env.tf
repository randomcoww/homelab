locals {
  aws_region       = "us-west-2"
  ignition_version = "1.5.0"

  mounts = {
    containers_path = "/var/lib/containers"
    home_path       = "/var/home"
  }
  # Setting to 9000 seems to reduce success rate of PXE boot
  default_mtu = 1500

  base_networks = {
    lan = {
      network            = "192.168.126.0"
      cidr               = 23
      vlan_id            = 1
      enable_mdns        = true
      enable_dhcp_server = true
      enable_dns         = true
      netnums = {
        gateway = 2
      }
    }
    sync = {
      network = "192.168.190.0"
      cidr    = 29
      vlan_id = 60
      mtu     = local.default_mtu
    }
    etcd = {
      network = "192.168.191.0"
      cidr    = 29
      vlan_id = 70
      mtu     = local.default_mtu
    }
    service = {
      network = "192.168.192.0"
      cidr    = 26
      vlan_id = 80
      netnums = {
        external_dns           = 31
        ingress_nginx          = 32
        ingress_nginx_external = 35
        matchbox               = 33
        minio                  = 34
        sunshine               = 36
        alpaca_stream          = 37
        alpaca_db              = 38
      }
      mtu = local.default_mtu
    }
    kubernetes = {
      network = "192.168.193.0"
      cidr    = 26
      vlan_id = 90
      netnums = {
        apiserver = 4
      }
      mtu = local.default_mtu
    }
    wan = {
      vlan_id = 30
      mac     = "52-54-00-63-6e-b3"
    }
    mobile = {
    }
    kubernetes_service = {
      network = "10.96.0.0"
      cidr    = 12
      netnums = {
        cluster_apiserver     = 1
        cluster_dns           = 10
        cluster_kea_primary   = 12
        cluster_kea_secondary = 13
      }
    }
    kubernetes_pod = {
      network = "10.244.0.0"
      cidr    = 16
    }
  }

  container_images = {
    # Igntion
    kube_apiserver          = "ghcr.io/randomcoww/kubernetes:kube-master-v${local.kubernetes.version}"
    kube_controller_manager = "ghcr.io/randomcoww/kubernetes:kube-master-v${local.kubernetes.version}"
    kube_scheduler          = "ghcr.io/randomcoww/kubernetes:kube-master-v${local.kubernetes.version}"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:20240226.2"
    etcd                    = "gcr.io/etcd-development/etcd:v3.5.12-amd64"

    # Helm
    kea                = "ghcr.io/randomcoww/kea:2.4.1"
    matchbox           = "quay.io/poseidon/matchbox:v0.11.0-amd64"
    tftpd              = "ghcr.io/randomcoww/tftpd-ipxe:20240104.0"
    hostapd            = "ghcr.io/randomcoww/hostapd:2.10-2"
    syncthing          = "docker.io/syncthing/syncthing:1.27"
    rclone             = "docker.io/rclone/rclone:1.66"
    flannel            = "docker.io/flannel/flannel:v0.25.2"
    flannel_cni_plugin = "docker.io/flannel/flannel-cni-plugin:v1.4.1-flannel1"
    kapprover          = "ghcr.io/randomcoww/kapprover:20240126"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.14.2"
    kube_proxy         = "ghcr.io/randomcoww/kubernetes:kube-proxy-v${local.kubernetes.version}"
    transmission       = "ghcr.io/randomcoww/transmission:20240615.1"
    wireguard          = "ghcr.io/randomcoww/wireguard:20240523"
    vaultwarden        = "docker.io/vaultwarden/server:1.30.5-alpine"
    litestream         = "docker.io/litestream/litestream:0.3"
    tailscale          = "ghcr.io/randomcoww/tailscale:1.66.4"
    fuse_device_plugin = "docker.io/soolaugust/fuse-device-plugin:v1.0"
    jupyter            = "ghcr.io/randomcoww/code-server:20240617.6-jupyter"
    alpaca_stream      = "ghcr.io/randomcoww/alpaca-client:stream-server-20240404.20"
    lldap              = "docker.io/lldap/lldap:2024-05-06"
    bsimp              = "ghcr.io/randomcoww/bsimp:20240523.2"
    keydb              = "docker.io/eqalpha/keydb:alpine_x86_64_v6.3.4"
    clickhouse         = "docker.io/clickhouse/clickhouse-server:24.4-alpine"
    juicefs            = "ghcr.io/randomcoww/juicefs:1.1.2"
  }

  pxeboot_images = {
    coreos     = "fedora-coreos-39.20240518.0"
    silverblue = "fedora-silverblue-39.20240606.0"
  }

  kubernetes = {
    version                   = "1.29.2"
    cluster_name              = "prod-10"
    kubelet_root_path         = "/var/lib/kubelet"
    static_pod_manifest_path  = "/var/lib/kubelet/manifests"
    cni_bridge_interface_name = "cni0"

    cert_issuer_prod    = "letsencrypt-prod"
    cert_issuer_staging = "letsencrypt-staging"

    kubelet_client_user     = "kube-apiserver-kubelet-client"
    front_proxy_client_user = "front-proxy-client"
    node_bootstrap_user     = "system:node-bootstrapper"
  }

  vrrp = {
    haproxy_config_path    = "/etc/haproxy/haproxy.cfg.d"
    keepalived_config_path = "/etc/keepalived/keepalived.conf.d"
  }

  domains = {
    mdns       = "local"
    public     = "fuzzybunny.win"
    kubernetes = "cluster.internal"
    tailscale  = "fawn-turtle.ts.net"
  }

  kubernetes_ingress_endpoints = {
    for k, domain in {
      auth          = "auth"
      transmission  = "t"
      minio         = "minio"
      vaultwarden   = "vw"
      matchbox      = "ign"
      jupyter       = "jupyter"
      alpaca_stream = "alpaca-stream"
      alpaca_db     = "alpaca-db"
      lldap_http    = "ldap"
      bsimp         = "bsimp"
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
      authelia = {
        name      = "authelia"
        namespace = "authelia"
      }
      authelia_redis = {
        name      = "redis"
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
      alpaca_stream = {
        name      = "alpaca-stream"
        namespace = "alpaca"
      }
      alpaca_db = {
        name      = "alpaca-db"
        namespace = "alpaca"
      }
    } :
    name => merge(e, {
      endpoint = "${e.name}.${e.namespace}"
      fqdn     = "${e.name}.${e.namespace}.svc.${local.domains.kubernetes}"
    })
  }

  host_ports = {
    kea_peer           = 50060
    tftpd              = 69
    apiserver          = 58081
    apiserver_backend  = 58181
    controller_manager = 50252
    scheduler          = 50251
    kubelet            = 50250
    kube_proxy         = 50254
    etcd_client        = 58082
    etcd_peer          = 58083
  }

  service_ports = {
    matchbox      = 80
    matchbox_api  = 50101
    minio         = 9000
    alpaca_stream = 38081
    lldap         = 6360
    redis         = 6379
  }

  minio_buckets = {
    boot = {
      name   = "boot"
      policy = "download"
    }
    music = {
      name   = "music"
      policy = "none"
    }
    downloads = {
      name   = "downloads"
      policy = "public"
    }
    pictures = {
      name   = "pictures"
      policy = "none"
    }
    videos = {
      name   = "videos"
      policy = "none"
    }
    backup = {
      name   = "backup"
      policy = "none"
    }
    juicefs = {
      name   = "juicefs"
      policy = "none"
    }
    clickhouse = {
      name   = "clickhouse"
      policy = "none"
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

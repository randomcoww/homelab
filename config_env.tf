locals {
  timezone         = "America/Los_Angeles"
  aws_region       = "us-west-2"
  ignition_version = "1.5.0"

  mounts = {
    containers_path = "/var/lib/containers"
    home_path       = "/var/home"
  }
  # Setting to 9000 seems to reduce success rate of PXE boot
  default_mtu = 1500

  base_networks = {
    # Kubernetes worker and netboot
    node = {
      network     = "192.168.192.0"
      cidr        = 24
      vlan_id     = 2048
      mtu         = local.default_mtu
      enable_dns  = true
      enable_mdns = true
      netnums = {
        gateway = 2
        switch  = 127
      }
    }
    # Kubernetes service external IP and LB
    service = {
      network = "192.168.208.0"
      cidr    = 24
      vlan_id = 80
      mtu     = local.default_mtu
      netnums = {
        service_apiserver      = 2
        external_dns           = 31
        ingress_nginx          = 32
        ingress_nginx_external = 35
        matchbox               = 39
        matchbox_api           = 33
        minio                  = 34
        sunshine               = 36
        alpaca_db              = 38
      }
    }
    # VRRP conntrack sync
    sync = {
      network = "192.168.224.0"
      cidr    = 26
      vlan_id = 60
      mtu     = local.default_mtu
    }
    # Etcd peering
    etcd = {
      network = "192.168.228.0"
      cidr    = 26
      vlan_id = 70
      mtu     = local.default_mtu
    }
    # Kubernetes master
    kubernetes = {
      network = "192.168.232.0"
      cidr    = 26
      vlan_id = 90
      mtu     = local.default_mtu
      netnums = {
        apiserver = 2
      }
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
        cluster_dns_mdns      = 15
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
    accept    = "0x00002000"
    wireguard = "0x00008000"
  }

  container_images = {
    # Igntion
    kube_apiserver          = "ghcr.io/randomcoww/kubernetes:kube-master-${local.kubernetes.version}"
    kube_controller_manager = "ghcr.io/randomcoww/kubernetes:kube-master-${local.kubernetes.version}"
    kube_scheduler          = "ghcr.io/randomcoww/kubernetes:kube-master-${local.kubernetes.version}"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:20240923.12"
    etcd                    = "gcr.io/etcd-development/etcd:v3.5.15-amd64"

    # Helm
    kea                = "ghcr.io/randomcoww/kea:2.6.1"
    matchbox           = "quay.io/poseidon/matchbox:v0.11.0-amd64"
    tftpd              = "ghcr.io/randomcoww/tftpd-ipxe:20240822.3"
    hostapd            = "ghcr.io/randomcoww/hostapd:2.10-2"
    flannel            = "docker.io/flannel/flannel:v0.25.6"
    flannel_cni_plugin = "docker.io/flannel/flannel-cni-plugin:v1.5.1-flannel3"
    kapprover          = "ghcr.io/randomcoww/kapprover:20240126"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.14.2"
    kube_proxy         = "ghcr.io/randomcoww/kubernetes:kube-proxy-${local.kubernetes.version}"
    vaultwarden        = "docker.io/vaultwarden/server:1.32.4-alpine"
    litestream         = "docker.io/litestream/litestream:0.3"
    tailscale          = "ghcr.io/randomcoww/tailscale:1.74.0"
    fuse_device_plugin = "docker.io/soolaugust/fuse-device-plugin:v1.0"
    code_server        = "ghcr.io/randomcoww/code-server:4.96.2"
    lldap              = "docker.io/lldap/lldap:2024-08-08-alpine"
    keydb              = "docker.io/eqalpha/keydb:alpine_x86_64_v6.3.4"
    clickhouse         = "docker.io/clickhouse/clickhouse-server:24.8-alpine"
    jfs                = "ghcr.io/randomcoww/juicefs:1.2.1"
    qrcode_generator   = "ghcr.io/randomcoww/qrcode-generator:20240620.4"
    rclone             = "docker.io/rclone/rclone:1.68"
    cockroachdb        = "docker.io/cockroachdb/cockroach:v24.1.1"
    mountpoint         = "ghcr.io/randomcoww/mountpoint:20240915.5"
    audioserve         = "docker.io/izderadicka/audioserve:latest"
    syncthing          = "docker.io/syncthing/syncthing:1.27"
    kube_vip           = "ghcr.io/kube-vip/kube-vip:v0.8.7"
    sunshine_desktop   = "ghcr.io/randomcoww/sunshine-desktop:2024.1230.200248-5"
    nvidia_driver      = "ghcr.io/randomcoww/nvidia-driver:565.77-fedora41"
    coredns_mdns       = "ghcr.io/randomcoww/coredns:1.12.0"
  }

  pxeboot_images = {
    coreos = "fedora-coreos-41.20250103.0"
  }

  kubernetes = {
    version                   = "1.31.1"
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

  ha = {
    haproxy_config_path    = "/etc/haproxy/haproxy.cfg.d"
    keepalived_config_path = "/etc/keepalived/keepalived.conf.d"
    bird_config_path       = "/etc/bird.conf.d"
    bird_cache_table_name  = "cache"
    bgp_as_gateway         = 65001
    bgp_as_apiserver       = 65002
    bgp_as_service         = 65003
  }

  domains = {
    mdns       = "local"
    public     = "fuzzybunny.win"
    kubernetes = "cluster.internal"
    tailscale  = "fawn-turtle.ts.net"
  }

  kubernetes_ingress_endpoints = {
    for k, domain in {
      auth            = "auth"
      vaultwarden     = "vw"
      code            = "code"
      alpaca_db       = "alpaca-db"
      lldap_http      = "ldap"
      qrcode          = "qrcode"
      qrcode_wifi     = "wifi"
      webdav_pictures = "pictures"
      webdav_videos   = "videos"
      sunshine        = "sunshine"
      sunshine_admin  = "sunadmin"
      audioserve      = "audioserve"
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
      apiserver_external = {
        name      = "kube-apiserver"
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
    flannel_healthz    = 58084
    code               = 58085
    bgp                = 179
    mdns_lookup        = 50053
  }

  service_ports = {
    matchbox     = 80
    matchbox_api = 50101
    minio        = 9000
    lldap        = 6360
    redis        = 6379
    cockroachdb  = 26258
  }

  minio_data_buckets = {
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

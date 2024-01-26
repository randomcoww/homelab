locals {
  aws_region = "us-west-2"

  mounts = {
    containers_path = "/var/lib/containers"
    home_path       = "/var/home"
  }

  # do not use #
  base_networks = {
    lan = {
      network            = "192.168.126.0"
      cidr               = 23
      vlan_id            = 1
      enable_mdns        = true
      enable_dhcp_server = true
      enable_dns         = true
      mtu                = 9000
      netnums = {
        gateway = 2
      }
    }
    sync = {
      network = "192.168.190.0"
      cidr    = 29
      vlan_id = 60
      mtu     = 9000
    }
    etcd = {
      network = "192.168.191.0"
      cidr    = 29
      vlan_id = 70
      mtu     = 9000
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
      }
      mtu = 9000
    }
    kubernetes = {
      network = "192.168.193.0"
      cidr    = 26
      vlan_id = 90
      netnums = {
        apiserver = 4
      }
      mtu = 9000
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
    headscale = {
      network = "100.64.0.0"
      cidr    = 16
    }
  }

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

  container_images = {
    # Igntion
    kube_apiserver          = "ghcr.io/randomcoww/kubernetes:kube-master-v${local.kubernetes.version}"
    kube_controller_manager = "ghcr.io/randomcoww/kubernetes:kube-master-v${local.kubernetes.version}"
    kube_scheduler          = "ghcr.io/randomcoww/kubernetes:kube-master-v${local.kubernetes.version}"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:20240126.5"
    etcd                    = "gcr.io/etcd-development/etcd:v3.5.8-amd64"

    # Helm
    kea                = "ghcr.io/randomcoww/kea:2.4.1"
    matchbox           = "quay.io/poseidon/matchbox:v0.10.0-13-gd0d5e9d5-amd64"
    tftpd              = "ghcr.io/randomcoww/tftpd-ipxe:20240104.0"
    hostapd            = "ghcr.io/randomcoww/hostapd:2.10"
    syncthing          = "docker.io/syncthing/syncthing:1.27"
    rclone             = "docker.io/rclone/rclone:1.65"
    mpd                = "ghcr.io/randomcoww/mpd:0.23.15.2-s6"
    mympd              = "ghcr.io/jcorporation/mympd/mympd:13.0.6"
    flannel            = "docker.io/flannel/flannel:v0.24.0"
    flannel_cni_plugin = "docker.io/flannel/flannel-cni-plugin:v1.2.0"
    kapprover          = "ghcr.io/randomcoww/kapprover:latest"
    external_dns       = "registry.k8s.io/external-dns/external-dns:v0.14.0"
    kube_proxy         = "ghcr.io/randomcoww/kubernetes:kube-proxy-v${local.kubernetes.version}"
    transmission       = "ghcr.io/randomcoww/transmission:20240108.1"
    wireguard          = "ghcr.io/randomcoww/wireguard:20240109"
    vaultwarden        = "docker.io/vaultwarden/server:1.30.1-alpine"
    litestream         = "docker.io/litestream/litestream:latest"
    tailscale          = "ghcr.io/randomcoww/tailscale:1.56.1"
    fuse_device_plugin = "docker.io/soolaugust/fuse-device-plugin:v1.0"
    code_server        = "ghcr.io/randomcoww/code-server:20240118.1-tensorflow"
    kasm_desktop       = "ghcr.io/randomcoww/kasm-desktop:20231220.3"
    alpaca_stream      = "ghcr.io/randomcoww/alpaca-stream-server:20230518.1"
    headscale          = "docker.io/headscale/headscale:0.22"
  }

  kubernetes = {
    version                   = "1.29.0"
    cluster_name              = "prod-10"
    kubelet_root_path         = "/var/lib/kubelet"
    static_pod_manifest_path  = "/var/lib/kubelet/manifests"
    cni_bridge_interface_name = "cni0"

    cert_issuer_prod    = "letsencrypt-prod"
    cert_issuer_staging = "letsencrypt-staging"

    kubelet_access_user = "kube-apiserver-kubelet-client"
    node_bootstrap_user = "system:node-bootstrapper"
  }

  domains = {
    internal_mdns = "local"
    internal      = "fuzzybunny.win"
    kubernetes    = "cluster.internal"
    tailscale     = "fawn-turtle.ts.net"
  }

  kubernetes_ingress_endpoints = {
    mpd           = "mpd.${local.domains.internal}"
    auth          = "auth.${local.domains.internal}"
    transmission  = "t.${local.domains.internal}"
    minio         = "m.${local.domains.internal}"
    vaultwarden   = "vw.${local.domains.internal}"
    matchbox      = "ign.${local.domains.internal}"
    code_server   = "code.${local.domains.internal}"
    kasm          = "k.${local.domains.internal}"
    sunshine      = "sun.${local.domains.internal}"
    alpaca_stream = "alpaca-stream.${local.domains.internal}"
    speedtest     = "speedtest.${local.domains.internal}"
    headscale     = "headscale.${local.domains.internal}"
  }

  ingress_classes = {
    ingress_nginx          = "ingress-nginx"
    ingress_nginx_external = "ingress-nginx-external"
  }

  kubernetes_service_endpoints = {
    apiserver              = "kubernetes.default.svc.${local.domains.kubernetes}"
    authelia               = "authelia.authelia.svc.${local.domains.kubernetes}"
    ingress_nginx          = "${local.ingress_classes.ingress_nginx}-controller.ingress-nginx"
    ingress_nginx_external = "${local.ingress_classes.ingress_nginx_external}-controller.ingress-nginx"
    minio                  = "minio.minio"
  }

  ports = {
    gateway_dns        = 53
    kea_peer           = 50060
    tftpd              = 69
    apiserver_ha       = 58081
    apiserver          = 58181
    controller_manager = 50252
    scheduler          = 50251
    kubelet            = 50250
    kube_proxy         = 50254
    etcd_client        = 58082
    etcd_peer          = 58083
    matchbox           = 80
    matchbox_api       = 50101
  }

  service_ports = {
    minio         = 9000
    transmission  = 9091
    alpaca_stream = 38081
  }

  minio_buckets = {
    boot = {
      name   = "boot"
      policy = "download"
    }
    music = {
      name   = "music"
      policy = "download"
    }
    mpd = {
      name   = "mpd"
      policy = "public"
    }
    downloads = {
      name   = "downloads"
      policy = "upload"
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
  }

  upstream_dns = {
    ip             = "1.1.1.1"
    tls_servername = "one.one.one.one"
  }
}
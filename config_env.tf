locals {
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
      enable_gateway     = true
      enable_dhcp_server = true
      mtu                = 9000
      netnums = {
        gateway = 2
        tftp    = 2
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
        external_dns     = 31
        external_ingress = 32
        matchbox         = 33
        minio            = 34
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
    fallback = {
      metric = 512
    }
    kubernetes_service = {
      network = "10.96.0.0"
      cidr    = 12
      netnums = {
        cluster_apiserver     = 1
        cluster_dns           = 10
        cluster_external_dns  = 11
        cluster_kea_primary   = 12
        cluster_kea_secondary = 13
      }
    }
    kubernetes_pod = {
      network = "10.244.0.0"
      cidr    = 16
    }
  }

  networks = merge(local.base_networks, {
    for network_name, network in local.base_networks :
    network_name => merge(network, try({
      name          = network_name
      prefix        = "${network.network}/${network.cidr}"
      enable_prefix = true
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
    kube_apiserver          = "ghcr.io/randomcoww/kubernetes:kube-master-v1.27.1"
    kube_controller_manager = "ghcr.io/randomcoww/kubernetes:kube-master-v1.27.1"
    kube_scheduler          = "ghcr.io/randomcoww/kubernetes:kube-master-v1.27.1"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:latest"
    etcd                    = "gcr.io/etcd-development/etcd:v3.5.8-amd64"

    # Helm
    kea                = "ghcr.io/randomcoww/kea:2.2.0"
    matchbox           = "quay.io/poseidon/matchbox:v0.10.0-13-gd0d5e9d5-amd64"
    coredns            = "docker.io/coredns/coredns:1.10.1"
    tftpd              = "ghcr.io/randomcoww/tftpd-ipxe:20230429"
    hostapd            = "ghcr.io/randomcoww/hostapd:2.10"
    syncthing          = "docker.io/syncthing/syncthing:1.23"
    rclone             = "docker.io/rclone/rclone:1.62"
    mpd                = "ghcr.io/randomcoww/mpd:0.23.12"
    mympd              = "ghcr.io/jcorporation/mympd/mympd:10.3.1"
    flannel            = "docker.io/flannelcni/flannel:v0.21.0-amd64"
    flannel_cni_plugin = "docker.io/flannelcni/flannel-cni-plugin:v1.2.0-amd64"
    kapprover          = "ghcr.io/randomcoww/kapprover:latest"
    external_dns       = "k8s.gcr.io/external-dns/external-dns:v0.13.4"
    kube_proxy         = "ghcr.io/randomcoww/kubernetes:kube-proxy-v1.27.1"
    transmission       = "ghcr.io/randomcoww/transmission:20230429"
    wireguard          = "ghcr.io/randomcoww/wireguard:20230429"
    vaultwarden        = "docker.io/vaultwarden/server:1.29.0-alpine"
    litestream         = "docker.io/litestream/litestream:latest"
    cloudflared        = "docker.io/cloudflare/cloudflared:2023.6.0-amd64"
    tailscale          = "ghcr.io/randomcoww/tailscale:1.44.0"
    dev                = "ghcr.io/randomcoww/dev:20230720"
    fuse_device_plugin = "soolaugust/fuse-device-plugin:v1.0"
  }

  kubernetes = {
    etcd_cluster_token        = "prod-9"
    cluster_name              = "prod-9"
    static_pod_manifest_path  = "/var/lib/kubelet/manifests"
    cni_bridge_interface_name = "cni0"
  }

  domains = {
    internal_mdns = "local"
    internal      = "fuzzybunny.win"
    kubernetes    = "cluster.internal"
  }

  kubernetes_ingress_endpoints = {
    mpd          = "mpd.${local.domains.internal}"
    auth         = "auth.${local.domains.internal}"
    transmission = "t.${local.domains.internal}"
    minio        = "m.${local.domains.internal}"
    pl           = "pl.${local.domains.internal}"
    vaultwarden  = "vw.${local.domains.internal}"
    webdav       = "w.${local.domains.internal}"
    matchbox     = "ign.${local.domains.internal}"
    dev          = "dev.${local.domains.internal}"
  }

  kubernetes_service_endpoints = {
    kubernetes = "kubernetes.default.svc.${local.domains.kubernetes}"
    minio      = "minio.minio.svc.${local.domains.kubernetes}"
    authelia   = "authelia.authelia.svc.${local.domains.kubernetes}"
    nginx      = "ingress-nginx-controller.ingress-nginx.svc.${local.domains.kubernetes}"
    webdav     = "webdav.default.svc.${local.domains.kubernetes}"
  }

  ports = {
    kea_peer           = 50060
    gateway_dns        = 53
    pxe_tftp           = 69
    apiserver          = 58081
    apiserver_internal = 58181
    controller_manager = 50252
    scheduler          = 50251
    kubelet            = 50250
    kube_proxy         = 50254
    etcd_client        = 58082
    etcd_peer          = 58083
    matchbox           = 80
    matchbox_api       = 50101
    minio              = 80
    transmission       = 9091
    vaultwarden        = 8080
    dev                = 8080
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
    downloads = {
      name   = "downloads"
      policy = "none"
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
      policy = "download"
    }
  }

  upstream_dns = {
    ip             = "9.9.9.9"
    tls_servername = "dns.quad9.net"
  }
}
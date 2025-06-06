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
        apiserver    = 2
        external_dns = 31
        matchbox     = 32
        matchbox_api = 33
        minio        = 34
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
    kube_apiserver          = "ghcr.io/randomcoww/kubernetes:v1.33.0.20250501.2313"
    kube_controller_manager = "ghcr.io/randomcoww/kubernetes:v1.33.0.20250501.2313"
    kube_scheduler          = "ghcr.io/randomcoww/kubernetes:v1.33.0.20250501.2313"
    kube_proxy              = "ghcr.io/randomcoww/kubernetes:v1.32.3.20250405.0152"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:v0.4.2"
    etcd                    = "gcr.io/etcd-development/etcd:v3.6.0"
    flannel                 = "docker.io/flannel/flannel:v0.27.0"
    flannel_cni_plugin      = "docker.io/flannel/flannel-cni-plugin:v1.7.1-flannel1"
    kube_vip                = "ghcr.io/kube-vip/kube-vip:v0.9.1"
    kvm_device_plugin       = "ghcr.io/randomcoww/kvm-device-plugin:v20250211.0006"
    kea                     = "ghcr.io/randomcoww/kea:v2.7.9.20250601.2313"
    matchbox                = "quay.io/poseidon/matchbox:v0.11.0"
    ipxe                    = "ghcr.io/randomcoww/ipxe:v20250601.2122"
    ipxe_tftp               = "ghcr.io/randomcoww/ipxe:v20250601.2120-tftp"
    hostapd                 = "ghcr.io/randomcoww/hostapd-noscan:v20250406.1002"
    kapprover               = "ghcr.io/randomcoww/kapprover:v0.1.0"
    external_dns            = "registry.k8s.io/external-dns/external-dns:v0.17.0"
    code_server             = "ghcr.io/randomcoww/code-server:v4.100.2.20250601.2107"
    litestream              = "ghcr.io/randomcoww/litestream:v0.3.13.20250405.0151"
    tailscale               = "ghcr.io/randomcoww/tailscale-nft:v1.84.0.20250601.2109"
    lldap                   = "ghcr.io/lldap/lldap:2025-05-19-alpine-rootless"
    keydb                   = "docker.io/eqalpha/keydb:alpine_x86_64_v6.3.4"
    clickhouse              = "docker.io/clickhouse/clickhouse-server:25.5.2.47-alpine"
    qrcode_generator        = "ghcr.io/randomcoww/qrcode-generator:v0.1.0"
    rclone                  = "docker.io/rclone/rclone:1.69.3"
    mountpoint              = "ghcr.io/randomcoww/mountpoint-s3:v1.18.0.20250601.2309"
    audioserve              = "docker.io/izderadicka/audioserve:latest"
    sunshine_desktop        = "ghcr.io/randomcoww/sunshine-desktop:v2025.404.171304.20250404.2119"
    nvidia_driver           = "registry.gitlab.com/container-toolkit-fcos/driver:570.133.20-fedora42"
    stork_agent             = "ghcr.io/randomcoww/stork-agent:v20250603.1911"
    steamcmd                = "ghcr.io/randomcoww/steamcmd:v20250601.2322"
    vaultwarden             = "docker.io/vaultwarden/server:1.34.1-alpine"
    llama_cpp               = "ghcr.io/ggml-org/llama.cpp:server-cuda"
    nginx                   = "docker.io/nginx:1.27-alpine-slim"
    s3fs                    = "ghcr.io/randomcoww/s3fs:v20250601.2322"
  }

  pxeboot_images = {
    latest = "fedora-coreos-42.20250604.16" # randomcoww/fedora-coreos-config-custom
  }

  kubernetes = {
    cluster_name              = "prod-10"
    kubelet_root_path         = "/var/lib/kubelet"
    static_pod_manifest_path  = "/var/lib/kubelet/manifests"
    containers_path           = "/var/lib/containers"
    cni_bin_path              = "/var/lib/cni/bin"
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
      auth            = "auth"
      vaultwarden     = "vw"
      code            = "code"
      lldap_http      = "ldap"
      qrcode_hostapd  = "hostapd"
      webdav_pictures = "pictures"
      webdav_videos   = "videos"
      sunshine_admin  = "sunadmin"
      audioserve      = "audioserve"
      monitoring      = "m"
      llama_cpp       = "llama"
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
      authelia = {
        name      = "authelia"
        namespace = "authelia"
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
    })
  }

  host_ports = {
    kea_peer           = 50060
    kea_metrics        = 58087
    kea_ctrl_agent     = 58088
    ipxe_tftp          = 69
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
    code               = 58085 # run code server on host net to work seamlessly with podman-remote
    bgp                = 179
    kube_vip_metrics   = 58089
  }

  service_ports = {
    matchbox     = 443
    matchbox_api = 50101
    minio        = 9000
    lldap        = 6360
    clickhouse   = 9440
    metrics      = 9153
    prometheus   = 80
    llama_cpp    = 80
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
      kernel = "${tag}-live-kernel.$${buildarch}"
      initrd = "${tag}-live-initramfs.$${buildarch}.img"
      rootfs = "${tag}-live-rootfs.$${buildarch}.img"
    }
  }
}

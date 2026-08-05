locals {
  timezone       = "America/Los_Angeles"
  butane_version = "1.5.0"

  networks = {
    for key, network in {
      # Client access
      lan = {
        interface      = "phy-lan"
        network        = "192.168.192.0"
        cidr           = 24
        vlan_id        = 2048
        table_id       = 220
        table_priority = 32760
        enable_netnum  = true
        vrrp_router_id = 13
        vips = {
          vrrp = 2
        }
      }
      # BGP
      node = {
        interface     = "phy-node"
        network       = "192.168.200.0"
        cidr          = 24
        vlan_id       = 60
        enable_netnum = true
      }
      # Kubernetes service external IP and LB
      service = {
        interface     = "phy-service"
        network       = "192.168.208.0"
        cidr          = 24
        vlan_id       = 80
        enable_netnum = true
      }
      # Etcd peering
      etcd = {
        interface     = "phy-etcd"
        network       = "192.168.228.0"
        cidr          = 26
        vlan_id       = 70
        enable_netnum = true
      }
      # Primary WAN
      wan = {
        interface      = "phy-wan"
        vlan_id        = 30
        enable_dhcp    = true
        table_id       = 250
        table_priority = 32770
        mac            = "52-54-00-63-6e-b3" # use same mac for VRRP WAN
      }
      # Cluster internal
      kubernetes_service = {
        network = "10.96.0.0"
        cidr    = 12
      }
      kubernetes_pod = {
        network = "10.244.0.0"
        cidr    = 16
      }
    } :
    key => merge(network, {
      key = key
      }, contains(keys(network), "network") && contains(keys(network), "cidr") ? {
      prefix = "${network.network}/${network.cidr}"
      } : {}, contains(keys(network), "network") && contains(keys(network), "cidr") ? {
      vips = {
        for service, netnum in lookup(network, "vips", {}) :
        service => cidrhost("${network.network}/${network.cidr}", netnum)
      }
    } : {})
  }

  # Host or hostNet container listen ports
  host_ports = {
    kea_peer           = 50060
    kea_metrics        = 58087
    ipxe_tftp          = 69 # not configurable
    ipxe               = 58090
    apiserver          = 58181
    apiserver_backend  = 58081
    controller_manager = 50252
    scheduler          = 50251
    kubelet            = 10250 # prometheus operator assumes this port and is not configurable
    etcd_client        = 58082
    etcd_peer          = 58083
    etcd_metrics       = 58086
    bgp                = 179 # not configurable
    crio_metrics       = 58091
  }

  # Kube clusterIP or loadbalancer listen ports
  service_ports = {
    minio           = 9000
    coredns_metrics = 9153
    registry        = 443 # not configurable
    ldaps           = 6360
    redis_sentinel  = 26379
    kubernetes_mcp  = 8080
  }

  bgp = {
    host_as    = 65005 # host bird
    cluster_as = 65006 # cilium
  }

  domain_regex = "(?<hostname>(?<subdomain>[a-z0-9-*]+)\\.(?<domain>[a-z0-9.-]+))(?::(?<port>\\d+))?"
  domains = {
    kubernetes = "cluster.internal"
    public     = "fuzzybunny.win"
  }

  upstream_dns = [
    {
      ip       = "1.1.1.1"
      hostname = "one.one.one.one"
    },
    {
      ip       = "1.0.0.1"
      hostname = "one.one.one.one"
    },
  ]

  kubernetes = {
    cluster_name             = "prod-10"
    kubelet_root_path        = "/var/lib/kubelet"
    static_pod_manifest_path = "/var/lib/kubelet/manifests"
    containers_path          = "/var/lib/containers"
    cni_bin_path             = "/var/lib/cni/bin"
    cni_config_path          = "/etc/cni/net.d"
    kubelet_client_user      = "kube-apiserver-kubelet-client"
    helm_release_timeout     = 600

    feature_gates = {
      ClusterTrustBundle                      = true
      ClusterTrustBundleProjection            = true
      InPlacePodLevelResourcesVerticalScaling = false # TODO: workaround for kubelet 1.36.x panic with doPodResizeAction
    }
  }

  endpoints = {
    for name, e in {

      ## system
      apiserver = {
        name           = "kubernetes"
        namespace      = "default"
        cluster_netnum = 1
      }
      apiserver-lb = {
        name           = "kube-apiserver"
        namespace      = "kube-system"
        service_netnum = 2
      }
      etcd = {
        name      = "etcd"
        namespace = "kube-system"
      }
      cilium = {
        name      = "cilium"
        namespace = "kube-system"
      }
      kube-dns = {
        name           = "kube-dns"
        namespace      = "kube-system"
        cluster_netnum = 10
      }
      k8s-gateway = {
        name           = "k8s-gateway"
        namespace      = "kube-system"
        service_netnum = 33
      }

      ## infra
      minio = {
        name           = "minio"
        namespace      = "minio"
        service_netnum = 34
      }
      fluxcd = {
        name      = "fluxcd"
        namespace = "flux-system"
      }
      cert-manager = {
        name      = "cert-manager"
        namespace = "cert-manager"
      }
      registry = {
        name           = "registry"
        namespace      = "registry"
        service        = "reg.${local.domains.kubernetes}"
        service_netnum = 35
      }
      # - kea needs a known IP for each peer -
      kea-primary = {
        cluster_netnum = 12
      }
      kea-secondary = {
        cluster_netnum = 13
      }
      prometheus = {
        name      = "prometheus"
        namespace = "monitoring"
      }
      mountpoint-s3-csi = {
        name      = "s3-csi"
        namespace = "s3-csi"
      }

      ## auth stack
      lldap = {
        name      = "lldap"
        namespace = "auth"
        ingress   = "ldap.${local.domains.public}"
      }
      authelia-valkey = {
        name      = "authelia-valkey"
        namespace = "auth"
      }
      authelia = {
        name      = "authelia"
        namespace = "auth"
        ingress   = "auth.${local.domains.public}"
        tunnel    = true
      }

      ## client services
      kubernetes-mcp = {
        name = "kubernetes-mcp"
      }
      searxng = {
        name = "searxng"
      }
      qrcode-hostapd = {
        name    = "qrcode-hostapd"
        ingress = "hostapd.${local.domains.public}"
      }
      llama-cpp = {
        name = "llama-cpp"
      }
      navidrome = {
        name   = "navidrome"
        tunnel = true
      }
      stump = {
        name   = "stump"
        tunnel = true
      }
      camofox-browser = {
        name = "camofox"
      }
      hermes-agent = {
        name = "hermes-agent"
      }
    } :
    name => merge(e, contains(keys(e), "name") ? {
      namespace    = lookup(e, "namespace", "default")
      service      = "${lookup(e, "service", "${e.name}.${lookup(e, "namespace", "default")}")}"
      service_fqdn = "${e.name}.${lookup(e, "namespace", "default")}.svc.${local.domains.kubernetes}"
      ingress      = "${lookup(e, "ingress", "${e.name}.${local.domains.public}")}"
      } : {}, contains(keys(e), "service_netnum") ? {
      service_ip = cidrhost(local.networks.service.prefix, e.service_netnum)
      } : {}, contains(keys(e), "cluster_netnum") ? {
      cluster_ip = cidrhost(local.networks.kubernetes_service.prefix, e.cluster_netnum)
    } : {})
  }
}
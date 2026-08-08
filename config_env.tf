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
        vips = {
          apiserver   = 2
          k8s-gateway = 33
          minio       = 34
          registry    = 35
        }
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
        vips = {
          apiserver     = 1
          kube-dns      = 10
          kea_primary   = 12 # kea needs a known IP for each peer
          kea_secondary = 13 # kea needs a known IP for each peer
        }
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

  services = {
    apiserver = {
      name      = "apiserver"
      namespace = "kube-system"
    }
    etcd = {
      name      = "etcd"
      namespace = "kube-system"
    }
    cilium = {
      name      = "cilium"
      namespace = "kube-system"
    }
    minio = {
      name      = "minio"
      namespace = "minio"
    }
    cert-manager = {
      name      = "cert-manager"
      namespace = "cert-manager"
    }
    victoria-metrics = {
      name      = "vm"
      namespace = "monitoring"
    }
  }

  httproutes = {
    registry = {
      hostname = "reg.${local.domains.kubernetes}"
    }
    lldap = {
      hostname = "ldap.${local.domains.public}"
    }
    authelia = {
      hostname = "auth.${local.domains.public}"
      tunnel   = true
    }
    hostapd-qrcode = {
      hostname = "hostapd.${local.domains.public}"
    }
    navidrome = {
      hostname = "navidrome.${local.domains.public}"
      tunnel   = true
    }
    stump = {
      hostname = "stump.${local.domains.public}"
      tunnel   = true
    }
    hermes-agent = {
      hostname = "hermes-agent.${local.domains.public}"
    }
    alertmanager = {
      hostname = "alertmanager.${local.domains.public}"
    }
  }

  # Host or hostNet container listen ports
  host_ports = {
    kea_peer           = 50060
    kea_metrics        = 58087
    ipxe_tftp          = 69 # not configurable
    ipxe               = 58090
    apiserver          = 58181
    apiserver_backend  = 58081 # apiserver behind haproxy
    controller-manager = 10257
    scheduler          = 10259
    kubelet            = 10250
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
  }
}
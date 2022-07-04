locals {
  # do not use #
  base_networks = {
    lan = {
      network = "192.168.126.0"
      cidr    = 23
      vlan_id = 1
      netnums = {
        apiserver      = 2
        forwarding_dns = 2
      }
    }
    sync = {
      network = "192.168.190.0"
      cidr    = 29
      vlan_id = 60
    }
    wan = {
      vlan_id = 30
    }
    metallb = {
      prefix = cidrsubnet("192.168.126.0/23", 2, 1)
      netnums = {
        external_dns     = 11
        internal_pxeboot = 12
        ingress          = 13
      }
    }
    kubernetes_service = {
      network = "10.96.0.0"
      cidr    = 12
      netnums = {
        apiserver = 1
        dns       = 10
      }
    }
    kubernetes_pod = {
      network = "10.244.0.0"
      cidr    = 16
    }
  }

  base_networks_temp_1 = merge(local.base_networks, {
    for network_name, network in local.base_networks :
    network_name => merge(network, try({
      prefix = "${network.network}/${network.cidr}"
    }, {}))
  })

  networks = merge(local.base_networks_temp_1, {
    for network_name, network in local.base_networks_temp_1 :
    network_name => merge(network, {
      vips = try({
        for service, netnum in network.netnums :
        service => cidrhost(network.prefix, netnum)
      }, {})
      }, try({
        dhcp_range = merge(network.dhcp_range, {
          prefix = cidrsubnet(network.prefix, network.dhcp_range.newbit, network.dhcp_range.netnum)
        })
    }, {}))
  })

  ports = {
    apiserver             = 58081
    controller_manager    = 50252
    scheduler             = 50251
    kubelet               = 50250
    kube_proxy            = 50254
    kea_peer              = 58080
    etcd_client           = 58082
    etcd_peer             = 58083
    internal_pxeboot_http = 80
    internal_pxeboot_api  = 50259
  }

  domains = {
    internal_mdns = "local"
    internal      = "fuzzybunny.internal"
    kubernetes    = "cluster.internal"
  }

  ingress = {
    minio         = "minio.${local.domains.internal}"
    minio_console = "mc.${local.domains.internal}"
    mpd_stream    = "s.${local.domains.internal}"
    mpd_control   = "mpd.${local.domains.internal}"
  }

  container_images = {
    kube_apiserver          = "ghcr.io/randomcoww/kubernetes:kube-master-v1.24.1"
    kube_controller_manager = "ghcr.io/randomcoww/kubernetes:kube-master-v1.24.1"
    kube_scheduler          = "ghcr.io/randomcoww/kubernetes:kube-master-v1.24.1"
    kube_proxy              = "ghcr.io/randomcoww/kubernetes:kube-proxy-v1.24.1"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:latest"
    etcd                    = "ghcr.io/randomcoww/etcd:v3.5.4"
    kea                     = "ghcr.io/randomcoww/kea:2.0.2"
    tftpd                   = "ghcr.io/randomcoww/tftpd-ipxe:master"
    coredns                 = "docker.io/coredns/coredns:latest"
    flannel                 = "ghcr.io/randomcoww/flannel:v0.18.1"
    flannel_cni_plugin      = "rancher/mirrored-flannelcni-flannel-cni-plugin:v1.1.0"
    kapprover               = "ghcr.io/randomcoww/kapprover:latest"
    external_dns            = "k8s.gcr.io/external-dns/external-dns:v0.12.0"
    matchbox                = "quay.io/poseidon/matchbox:latest"
    syncthing               = "docker.io/syncthing/syncthing:latest"
    rclone                  = "docker.io/rclone/rclone:latest"
    mpd                     = "ghcr.io/randomcoww/mpd:0.23.7"
    ympd                    = "ghcr.io/randomcoww/ympd:latest"
  }

  kubernetes = {
    etcd_cluster_token        = "prod-5"
    cluster_name              = "prod-5"
    static_pod_manifest_path  = "/var/lib/kubelet/manifests"
    cni_bridge_interface_name = "cni0"
    local_storage_class_path  = "/var/tmp/local_storage"
    local_storage_class       = "local-storage"
  }
}
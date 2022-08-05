locals {
  pv_mount_path = "/var/home"

  vrrp_netnum = 2

  # do not use #
  base_networks = {
    lan = {
      network            = "192.168.126.0"
      cidr               = 23
      vlan_id            = 1
      enable_mdns        = true
      enable_vrrp_netnum = true
      enable_dhcp_server = true
      mtu                = 9000
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
        external_ingress = 32
        matchbox         = 33
        minio            = 34
      }
      mtu = 9000
    }
    kubernetes = {
      network            = "192.168.193.0"
      cidr               = 26
      vlan_id            = 90
      enable_vrrp_netnum = true
      netnums = {
        apiserver = local.vrrp_netnum
      }
      mtu = 9000
    }
    wan = {
      vlan_id = 30
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

  vips = merge([
    for _, network in local.networks :
    try(network.vips)
    ]...
  )

  ports = {
    kea_peer           = 58080
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
    matchbox           = 50100
    matchbox_api       = 50101
    minio              = 9000
  }

  domains = {
    internal_mdns = "local"
    internal      = "fuzzybunny.mooo.com"
    kubernetes    = "cluster.internal"
  }

  ingress_hosts = {
    mpd   = "mpd.${local.domains.internal}"
    auth  = "auth.${local.domains.internal}"
    minio = "minio.${local.domains.internal}"
  }

  container_images = {
    # Igntion
    kube_apiserver          = "ghcr.io/randomcoww/kubernetes:kube-master-v1.24.1"
    kube_controller_manager = "ghcr.io/randomcoww/kubernetes:kube-master-v1.24.1"
    kube_scheduler          = "ghcr.io/randomcoww/kubernetes:kube-master-v1.24.1"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:latest"
    etcd                    = "ghcr.io/randomcoww/etcd:v3.5.4"

    # Helm
    kea                = "ghcr.io/randomcoww/kea:2.0.2"
    matchbox           = "quay.io/poseidon/matchbox:latest"
    coredns            = "docker.io/coredns/coredns:latest"
    tftpd              = "ghcr.io/randomcoww/tftpd-ipxe:20220804"
    hostapd            = "ghcr.io/randomcoww/hostapd:latest"
    syncthing          = "docker.io/syncthing/syncthing:latest"
    rclone             = "docker.io/rclone/rclone:latest"
    mpd                = "ghcr.io/randomcoww/mpd:0.23.8-2"
    ympd               = "ghcr.io/randomcoww/ympd:latest"
    flannel            = "ghcr.io/randomcoww/flannel:v0.18.1"
    flannel_cni_plugin = "rancher/mirrored-flannelcni-flannel-cni-plugin:v1.1.0"
    kapprover          = "ghcr.io/randomcoww/kapprover:latest"
    external_dns       = "k8s.gcr.io/external-dns/external-dns:v0.12.0"
    kube_proxy         = "ghcr.io/randomcoww/kubernetes:kube-proxy-v1.24.1"
  }

  kubernetes = {
    etcd_cluster_token        = "prod-6"
    cluster_name              = "prod-6"
    static_pod_manifest_path  = "/var/lib/kubelet/manifests"
    cni_bridge_interface_name = "cni0"
  }
}
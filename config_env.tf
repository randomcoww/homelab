locals {
  pv_mount_path = "/var/home"

  # do not use #
  base_networks = {
    lan = {
      network = "192.168.126.0"
      cidr    = 23
      vlan_id = 1
      netnums = {
        apiserver    = 2
        matchbox     = 2
        minio        = 2
        external_dns = 128
      }
    }
    sync = {
      network = "192.168.190.0"
      cidr    = 29
      vlan_id = 60
    }
    etcd = {
      network = "192.168.191.0"
      cidr    = 29
      vlan_id = 70
    }
    service = {
      network = "192.168.192.0"
      cidr    = 26
      vlan_id = 80
      netnums = {
        external_ingress = 32
      }
    }
    wan = {
      vlan_id = 30
    }
    kubernetes_service = {
      network = "10.96.0.0"
      cidr    = 12
      netnums = {
        cluster_apiserver = 1
        cluster_dns       = 10
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
    matchbox_http      = 30001
    matchbox_api       = 30002
    minio              = 30000
  }

  domains = {
    internal_mdns = "local"
    internal      = "fuzzybunny.mooo.com"
    kubernetes    = "cluster.internal"
  }

  container_images = {
    kube_apiserver          = "ghcr.io/randomcoww/kubernetes:kube-master-v1.24.1"
    kube_controller_manager = "ghcr.io/randomcoww/kubernetes:kube-master-v1.24.1"
    kube_scheduler          = "ghcr.io/randomcoww/kubernetes:kube-master-v1.24.1"
    etcd_wrapper            = "ghcr.io/randomcoww/etcd-wrapper:latest"
    etcd                    = "ghcr.io/randomcoww/etcd:v3.5.4"
    kea                     = "ghcr.io/randomcoww/kea:2.0.2"
    tftpd                   = "ghcr.io/randomcoww/tftpd-ipxe:master"
    coredns                 = "docker.io/coredns/coredns:latest"
  }

  kubernetes = {
    etcd_cluster_token        = "prod-6"
    cluster_name              = "prod-6"
    static_pod_manifest_path  = "/var/lib/kubelet/manifests"
    cni_bridge_interface_name = "cni0"
  }
}
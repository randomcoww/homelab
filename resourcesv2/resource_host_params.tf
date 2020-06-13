module "ssh-common" {
  source = "../modulesv2/ssh_common"

  user                  = local.user
  networks              = local.networks
  domains               = local.domains
  ssh_client_public_key = var.ssh_client_public_key

  templates = local.components.ssh.templates
  hosts = {
    for k in local.components.ssh.nodes :
    k => merge(local.hosts[k], {
      hostname     = join(".", [k, local.domains.mdns])
      host_network = local.host_network_by_type[k]
    })
  }
}

module "kubernetes-common" {
  source = "../modulesv2/kubernetes_common"

  aws_region            = local.aws_region
  user                  = local.user
  networks              = local.networks
  services              = local.services
  domains               = local.domains
  container_images      = local.container_images
  cluster_name          = local.kubernetes_cluster_name
  s3_etcd_backup_bucket = local.s3_etcd_backup_bucket
  addon_templates       = local.addon_templates

  controller_templates = local.components.controller.templates
  controller_hosts = {
    for k in local.components.controller.nodes :
    k => merge(local.hosts[k], {
      hostname     = join(".", [k, local.domains.mdns])
      host_network = local.host_network_by_type[k]
    })
  }

  worker_templates = local.components.worker.templates
  worker_hosts = {
    for k in local.components.worker.nodes :
    k => merge(local.hosts[k], {
      hostname     = join(".", [k, local.domains.mdns])
      host_network = local.host_network_by_type[k]
    })
  }
}

module "gateway-common" {
  source = "../modulesv2/gateway_common"

  user               = local.user
  mtu                = local.mtu
  networks           = local.networks
  loadbalancer_pools = local.loadbalancer_pools
  services           = local.services
  domains            = local.domains
  container_images   = local.container_images
  addon_templates    = local.addon_templates

  templates = local.components.gateway.templates
  hosts = {
    for k in local.components.gateway.nodes :
    k => merge(local.hosts[k], {
      hostname     = join(".", [k, local.domains.mdns])
      host_network = local.host_network_by_type[k]
    })
  }
}

module "test-common" {
  source = "../modulesv2/test_common"

  user             = local.user
  networks         = local.networks
  services         = local.services
  domains          = local.domains
  container_images = local.container_images

  templates = local.components.test.templates
  hosts = {
    for k in local.components.test.nodes :
    k => merge(local.hosts[k], {
      hostname     = join(".", [k, local.domains.mdns])
      host_network = local.host_network_by_type[k]
    })
  }
}

module "kvm-common" {
  source = "../modulesv2/kvm_common"

  user             = local.user
  mtu              = local.mtu
  networks         = local.networks
  services         = local.services
  domains          = local.domains
  container_images = local.container_images

  templates = local.components.kvm.templates
  hosts = {
    for k in local.components.kvm.nodes :
    k => merge(local.hosts[k], {
      hostname     = join(".", [k, local.domains.mdns])
      host_network = local.host_network_by_type[k]
    })
  }
}

module "desktop-common" {
  source = "../modulesv2/desktop_common"

  user     = local.desktop_user
  password = var.desktop_password
  mtu      = local.mtu
  networks = local.networks
  domains  = local.domains

  templates = local.components.desktop.templates
  hosts = {
    for k in local.components.desktop.nodes :
    k => merge(local.hosts[k], {
      hostname     = join(".", [k, local.domains.mdns])
      host_network = local.host_network_by_type[k]
    })
  }
}

##
## minio user-pass
##
resource "random_password" "minio-user" {
  length  = 30
  special = false
}

resource "random_password" "minio-password" {
  length  = 30
  special = false
}

##
## grafana user-pass
##
resource "random_password" "grafana-user" {
  length  = 30
  special = false
}

resource "random_password" "grafana-password" {
  length  = 30
  special = false
}

module "secrets" {
  source = "../modulesv2/secrets"

  addon_templates = local.addon_templates
  secrets = concat([
    {
      name      = "minio-auth"
      namespace = "minio"
      data = {
        access_key_id     = random_password.minio-user.result
        secret_access_key = random_password.minio-password.result
      }
    },
    {
      name      = "minio-auth"
      namespace = "common"
      data = {
        access_key_id     = random_password.minio-user.result
        secret_access_key = random_password.minio-password.result
      }
    },
    {
      name      = "grafana-auth"
      namespace = "monitoring"
      data = {
        user     = random_password.grafana-user.result
        password = random_password.grafana-password.result
      }
    }
    ],
    lookup(var.wireguard_config, "Interface", null) != null && lookup(var.wireguard_config, "Peer", null) != null ? [
      {
        name      = "wireguard-client"
        namespace = "common"
        data = {
          wireguard-client = <<EOF
[Interface]

%{~for k, v in merge({
  PostUp = <<EOT
nft add table ip filter && nft add chain ip filter output { type filter hook output priority 0 \; } && nft insert rule ip filter output oifname != "%i" mark != $(wg show %i fwmark) fib daddr type != local ip daddr != ${local.networks.kubernetes.network}/${local.networks.kubernetes.cidr} reject
EOT
}, var.wireguard_config.Interface)~}
${trimspace(k)} = ${trimspace(v)}

%{~endfor~}

[Peer]

%{~for k, v in merge({PersistentKeepalive = 25}, var.wireguard_config.Peer)~}
${trimspace(k)} = ${trimspace(v)}

%{~endfor~}
EOF
        }
      }
  ] : [])
}

module "tls-secrets" {
  source = "../modulesv2/tls_secrets"

  domains         = local.domains
  addon_templates = local.addon_templates
  secrets = [
    {
      name      = "tls-ingress"
      namespace = "traefik"
    },
    {
      name      = "tls-ingress"
      namespace = "minio"
    },
    {
      name      = "tls-ingress"
      namespace = "monitoring"
    },
    {
      name      = "tls-ingress"
      namespace = "common"
    }
  ]

  name      = "traefik-tls"
  templates = local.components.traefik_tls.templates
  hosts = {
    for k in local.components.traefik_tls.nodes :
    k => merge(local.hosts[k], {
      hostname     = join(".", [k, local.domains.mdns])
      host_network = local.host_network_by_type[k]
    })
  }
}

module "static-pod-logging" {
  source = "../modulesv2/static_pod_logging"

  services         = local.services
  container_images = local.container_images
  addon_templates  = local.addon_templates

  templates = local.components.static_pod_logging.templates
  hosts = {
    for k in local.components.static_pod_logging.nodes :
    k => merge(local.hosts[k], {
      hostname     = join(".", [k, local.domains.mdns])
      host_network = local.host_network_by_type[k]
    })
  }
}

module "common-guests" {
  source = "../modulesv2/common_guests"

  networks = local.networks

  libvirt_template = local.components.common_guests.libvirt_template
  hosts = {
    for k in local.components.common_guests.nodes :
    k => merge(local.hosts[k], {
      hostname     = join(".", [k, local.domains.mdns])
      host_network = local.host_network_by_type[k]
      network      = lookup(local.hosts[k], "network", [])
      hostdev      = lookup(local.hosts[k], "hostdev", [])
      disk = [
        for d in lookup(local.hosts[k], "disk", []) :
        d
        if lookup(d, "source", null) != null && lookup(d, "target", null) != null
      ]
    })
  }
}

# Write admin kubeconfig file
resource "local_file" "kubeconfig-admin" {
  content = templatefile(local.addon_templates.kubeconfig-admin, {
    cluster_name       = module.kubernetes-common.cluster_endpoint.cluster_name
    ca_pem             = replace(base64encode(chomp(module.kubernetes-common.cluster_endpoint.kubernetes_ca_pem)), "\n", "")
    cert_pem           = replace(base64encode(chomp(module.kubernetes-common.cluster_endpoint.kubernetes_cert_pem)), "\n", "")
    private_key_pem    = replace(base64encode(chomp(module.kubernetes-common.cluster_endpoint.kubernetes_private_key_pem)), "\n", "")
    apiserver_endpoint = module.kubernetes-common.cluster_endpoint.apiserver_endpoint
  })
  filename = "output/${module.kubernetes-common.cluster_endpoint.cluster_name}.kubeconfig"
}
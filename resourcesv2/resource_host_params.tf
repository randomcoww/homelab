module "ssh-common" {
  source = "../modulesv2/ssh_common"

  user                  = local.user
  domains               = local.domains
  ssh_client_public_key = var.ssh_client_public_key

  server_templates = local.components.ssh_server.ignition_templates
  server_hosts = {
    for k in local.components.ssh_server.nodes :
    k => local.aggr_hosts[k]
  }

  client_templates = local.components.ssh_client.ignition_templates
  client_hosts = {
    for k in local.components.ssh_client.nodes :
    k => local.aggr_hosts[k]
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

  controller_templates = local.components.controller.ignition_templates
  controller_hosts = {
    for k in local.components.controller.nodes :
    k => local.aggr_hosts[k]
  }

  worker_templates = local.components.worker.ignition_templates
  worker_hosts = {
    for k in local.components.worker.nodes :
    k => local.aggr_hosts[k]
  }
}

module "gateway-common" {
  source = "../modulesv2/gateway_common"

  user               = local.user
  loadbalancer_pools = local.loadbalancer_pools
  services           = local.services
  domains            = local.domains
  container_images   = local.container_images
  addon_templates    = local.addon_templates

  templates = local.components.gateway.ignition_templates
  hosts = {
    for k in local.components.gateway.nodes :
    k => local.aggr_hosts[k]
  }
}

module "test-common" {
  source = "../modulesv2/test_common"

  user             = local.user
  services         = local.services
  domains          = local.domains
  container_images = local.container_images

  templates = local.components.test.ignition_templates
  hosts = {
    for k in local.components.test.nodes :
    k => local.aggr_hosts[k]
  }
}

module "client" {
  source = "../modulesv2/client"

  client_password  = var.client_password
  domains          = local.domains
  wireguard_config = var.wireguard_config
  swap_device      = "/dev/disk/by-label/swap"

  templates = local.components.client.ignition_templates
  hosts = {
    for k in local.components.client.nodes :
    k => local.aggr_hosts[k]
  }
}

module "hypervisor" {
  source = "../modulesv2/hypervisor"

  user             = local.user
  services         = local.services
  container_images = local.container_images

  templates = local.components.hypervisor.ignition_templates
  hosts = {
    for k in local.components.hypervisor.nodes :
    k => local.aggr_hosts[k]
  }
}

module "vm" {
  source = "../modulesv2/vm"

  user      = local.user
  templates = local.components.vm.ignition_templates
  hosts = {
    for k in local.components.vm.nodes :
    k => local.aggr_hosts[k]
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

%{~for k, v in merge({
          PersistentKeepalive = 25
    }, var.wireguard_config.Peer)~}
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
  templates = local.components.traefik_tls.ignition_templates
  hosts = {
    for k in local.components.traefik_tls.nodes :
    k => local.aggr_hosts[k]
  }
}

module "static-pod-logging" {
  source = "../modulesv2/static_pod_logging"

  services         = local.services
  container_images = local.container_images
  addon_templates  = local.addon_templates

  templates = local.components.static_pod_logging.ignition_templates
  hosts = {
    for k in local.components.static_pod_logging.nodes :
    k => local.aggr_hosts[k]
  }
}

# Force output values to update
resource "null_resource" "output-triggers" {
  triggers = merge(
    module.kubernetes-common.cluster_endpoint,
    module.ssh-common.client_params
  )
}

locals {
  templates_by_host = {
    for h in keys(local.hosts) :
    h => flatten([
      for k in [
        module.kubernetes-common.controller_templates,
        module.kubernetes-common.worker_templates,
        module.gateway-common.templates,
        module.test-common.templates,
        module.ssh-common.server_templates,
        module.ssh-common.client_templates,
        module.static-pod-logging.templates,
        module.tls-secrets.templates,
        module.hypervisor.templates,
        module.vm.templates,
        module.client.templates,
      ] :
      lookup(k, h, [])
    ])
  }
}
module "template-base" {
  source = "../modules/template/base"

  hosts = {
    for k in local.components.base.nodes :
    k => local.aggr_hosts[k]
  }
}

module "template-ssh" {
  source = "../modules/template/ssh"

  users                 = local.aggr_users
  domains               = local.domains
  ssh_client_public_key = var.ssh_client_public_key
  server_hosts = {
    for k in local.components.ssh_server.nodes :
    k => local.aggr_hosts[k]
  }
  client_hosts = {
    for k in local.components.ssh_client.nodes :
    k => local.aggr_hosts[k]
  }
}

module "template-kubernetes" {
  source = "../modules/template/kubernetes"

  aws_region            = local.aws_region
  networks              = local.networks
  services              = local.services
  domains               = local.domains
  container_images      = local.container_images
  cluster_name          = local.kubernetes_cluster_name
  s3_etcd_backup_bucket = local.s3_etcd_backup_bucket
  controller_hosts = {
    for k in local.components.controller.nodes :
    k => local.aggr_hosts[k]
  }
  worker_hosts = {
    for k in local.components.worker.nodes :
    k => local.aggr_hosts[k]
  }
}

module "template-gateway" {
  source = "../modules/template/gateway"

  loadbalancer_pools = local.loadbalancer_pools
  services           = local.services
  domains            = local.domains
  container_images   = local.container_images
  hosts = {
    for k in local.components.gateway.nodes :
    k => local.aggr_hosts[k]
  }
}

module "template-ns" {
  source = "../modules/template/ns"

  services         = local.services
  domains          = local.domains
  container_images = local.container_images
  hosts = {
    for k in local.components.ns.nodes :
    k => local.aggr_hosts[k]
  }
}

module "template-server" {
  source = "../modules/template/server"

  users = local.aggr_users
  hosts = {
    for k in local.components.server.nodes :
    k => local.aggr_hosts[k]
  }
}

module "template-client" {
  source = "../modules/template/client"

  users            = local.aggr_users
  networks         = local.networks
  services         = local.services
  domains          = local.domains
  container_images = local.container_images
  wireguard_config = var.wireguard_config
  syncthing_directories = {
    "vscode" = "${local.aggr_users.client.home}/.vscode"
    "aws"    = "${local.aggr_users.client.home}/.aws"
    "ssh"    = "${local.aggr_users.client.home}/.ssh"
    "bin"    = "${local.aggr_users.client.home}/bin"
  }
  hosts = {
    for k in local.components.client.nodes :
    k => local.aggr_hosts[k]
  }
}

module "template-laptop" {
  source = "../modules/template/laptop"

  swap_device = "/dev/disk/by-label/swap"
  hosts = {
    for k in local.components.laptop.nodes :
    k => local.aggr_hosts[k]
  }
}

module "template-hypervisor" {
  source = "../modules/template/hypervisor"

  users            = local.aggr_users
  services         = local.services
  container_images = local.container_images
  hosts = {
    for k in local.components.hypervisor.nodes :
    k => local.aggr_hosts[k]
  }
}

module "template-vm" {
  source = "../modules/template/vm"

  container_images = local.container_images
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

##
## metallb secret
##
resource "random_string" "metallb-memberlist" {
  length  = 128
  special = false
}

##
## firefox sync secret
##
resource "random_string" "ffsync-secret-key" {
  length  = 128
  special = false
}

module "template-secrets" {
  source = "../modules/template/secrets"

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
    },
    {
      name      = "memberlist"
      namespace = "metallb-system"
      data = {
        secretkey = random_string.metallb-memberlist.result
      }
    },
    {
      name      = "ffsync-secret-key"
      namespace = "common"
      data = {
        secretkey = random_string.ffsync-secret-key.result
      }
    },
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

module "template-ingress" {
  source = "../modules/template/ingress"

  domains = local.domains
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
    },
  ]
  hosts = {
    for k in local.components.ingress.nodes :
    k => local.aggr_hosts[k]
  }
}

module "template-static-pod-logging" {
  source = "../modules/template/static_pod_logging"

  services         = local.services
  container_images = local.container_images
  hosts = {
    for k in local.components.static_pod_logging.nodes :
    k => local.aggr_hosts[k]
  }
}
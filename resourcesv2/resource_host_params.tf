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

  user     = var.desktop_user
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

  aws_region        = local.aws_region
  networks          = local.networks
  domains           = local.domains
  addon_templates   = local.addon_templates
  s3_secrets_bucket = local.s3_secrets_bucket
  s3_secrets_key    = local.s3_secrets_key

  secrets = {
    minio-auth-secret = {
      namespace = "default"
      data = {
        access_key_id     = random_password.minio-user.result
        secret_access_key = random_password.minio-password.result
      },
      type = "Opaque"
    },
    grafana-auth-secret = {
      namespace = "default"
      data = {
        user     = random_password.grafana-user.result
        password = random_password.grafana-password.result
      },
      type = "Opaque"
    }
  }

  internal_tls_templates = local.components.internal_tls.templates
  internal_tls_hosts = {
    for k in local.components.internal_tls.nodes :
    k => merge(local.hosts[k], {
      hostname     = join(".", [k, local.domains.mdns])
      host_network = local.host_network_by_type[k]
    })
  }

  wireguard_client_templates = local.components.wireguard_client.templates
  wireguard_client_hosts = {
    for k in local.components.wireguard_client.nodes :
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
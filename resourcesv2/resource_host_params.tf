module "ssh-common" {
  source = "../modulesv2/ssh_common"

  user                  = local.user
  networks              = local.networks
  domains               = local.domains
  ssh_client_public_key = var.ssh_client_public_key
  ssh_templates         = local.components.ssh.templates
  ssh_hosts = {
    for k in local.components.ssh.nodes :
    k => merge(local.hosts[k], {
      hostname     = join(".", [k, local.domains.mdns])
      host_network = local.host_network_by_type[k]
    })
  }
}

module "kubernetes-common" {
  source = "../modulesv2/kubernetes_common"

  cluster_name          = local.kubernetes_cluster_name
  s3_backup_aws_region  = local.s3_backup_aws_region
  s3_etcd_backup_bucket = local.s3_etcd_backup_bucket

  user             = local.user
  mtu              = local.mtu
  networks         = local.networks
  services         = local.services
  domains          = local.domains
  container_images = local.container_images

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

  gateway_templates = local.components.gateway.templates
  gateway_hosts = {
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
  mtu              = local.mtu
  networks         = local.networks
  services         = local.services
  domains          = local.domains
  container_images = local.container_images

  test_templates = local.components.test.templates
  test_hosts = {
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
  image_device     = local.image_device

  kvm_templates = local.components.kvm.templates
  kvm_hosts = {
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

  desktop_templates = local.components.desktop.templates
  desktop_hosts = {
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

module "kubernetes-addons" {
  source = "../modulesv2/kubernetes_addons"

  networks           = local.networks
  loadbalancer_pools = local.loadbalancer_pools
  services           = local.services
  domains            = local.domains
  container_images   = local.container_images
  addon_templates    = local.addon_templates

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
}

module "external-secrets" {
  source = "../modulesv2/external_secrets"

  networks          = local.networks
  addon_templates   = local.addon_templates
  s3_secrets_bucket = local.s3_secrets_bucket

  wireguard_client_templates = local.components.wireguard_client.templates
  wireguard_client_hosts = {
    for k in local.components.wireguard_client.nodes :
    k => merge(local.hosts[k], {
      hostname     = join(".", [k, local.domains.mdns])
      host_network = local.host_network_by_type[k]
    })
  }
}

# Write admin kubeconfig file
resource "local_file" "kubeconfig-admin" {
  content = templatefile("${path.module}/../templates/manifest/kubeconfig_admin.yaml.tmpl", {
    cluster_name       = module.kubernetes-common.cluster_endpoint.cluster_name
    ca_pem             = replace(base64encode(chomp(module.kubernetes-common.cluster_endpoint.kubernetes_ca_pem)), "\n", "")
    cert_pem           = replace(base64encode(chomp(module.kubernetes-common.cluster_endpoint.kubernetes_cert_pem)), "\n", "")
    private_key_pem    = replace(base64encode(chomp(module.kubernetes-common.cluster_endpoint.kubernetes_private_key_pem)), "\n", "")
    apiserver_endpoint = module.kubernetes-common.cluster_endpoint.apiserver_endpoint
  })
  filename = "output/${module.kubernetes-common.cluster_endpoint.cluster_name}.kubeconfig"
}
module "kubernetes-common" {
  source = "../modulesv2/kubernetes_common"

  cluster_name          = "default-cluster-012"
  s3_backup_aws_region  = "us-west-2"
  s3_etcd_backup_bucket = "randomcoww-etcd-backup"

  user              = local.user
  ssh_ca_public_key = tls_private_key.ssh-ca.public_key_openssh
  mtu               = local.mtu
  networks          = local.networks
  services          = local.services
  domains           = local.domains
  container_images  = local.container_images

  controller_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "controller")
  }

  worker_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "worker")
  }
}

module "gateway-common" {
  source = "../modulesv2/gateway_common"

  user              = local.user
  ssh_ca_public_key = tls_private_key.ssh-ca.public_key_openssh
  mtu               = local.mtu
  networks          = local.networks
  services          = local.services
  domains           = local.domains
  container_images  = local.container_images

  gateway_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "gateway")
  }
}

module "test-common" {
  source = "../modulesv2/test_common"

  user              = local.user
  ssh_ca_public_key = tls_private_key.ssh-ca.public_key_openssh
  mtu               = local.mtu
  networks          = local.networks
  services          = local.services
  domains           = local.domains
  container_images  = local.container_images

  test_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "test")
  }
}

module "kvm-common" {
  source = "../modulesv2/kvm_common"

  user              = local.user
  ssh_ca_public_key = tls_private_key.ssh-ca.public_key_openssh
  mtu               = local.mtu
  networks          = local.networks
  services          = local.services
  domains           = local.domains
  container_images  = local.container_images

  kvm_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "kvm")
  }
}

##
## Write config to each matchbox host
## Hardcode each matchbox host until for_each module becomes available
##
module "ignition-kvm-0" {
  source = "../modulesv2/ignition"

  controller_params = {
    for k in local.hosts.kvm-0.guests :
    k => module.kubernetes-common.controller_params[k]
    if lookup(module.kubernetes-common.controller_params, k, null) != null
  }
  worker_params = {
    for k in local.hosts.kvm-0.guests :
    k => module.kubernetes-common.worker_params[k]
    if lookup(module.kubernetes-common.worker_params, k, null) != null
  }
  gateway_params = {
    for k in local.hosts.kvm-0.guests :
    k => module.gateway-common.gateway_params[k]
    if lookup(module.gateway-common.gateway_params, k, null) != null
  }
  test_params = {
    for k in local.hosts.kvm-0.guests :
    k => module.test-common.test_params[k]
    if lookup(module.test-common.test_params, k, null) != null
  }
  kvm_params        = {}
  services          = local.services
  renderer          = module.kvm-common.matchbox_rpc_endpoints.kvm-0
  kernel_image      = local.kernel_image
  initrd_images     = local.initrd_images
  kernel_params     = local.kernel_params
}

module "ignition-kvm-1" {
  source = "../modulesv2/ignition"

  controller_params = {
    for k in local.hosts.kvm-1.guests :
    k => module.kubernetes-common.controller_params[k]
    if lookup(module.kubernetes-common.controller_params, k, null) != null
  }
  worker_params = {
    for k in local.hosts.kvm-1.guests :
    k => module.kubernetes-common.worker_params[k]
    if lookup(module.kubernetes-common.worker_params, k, null) != null
  }
  gateway_params = {
    for k in local.hosts.kvm-1.guests :
    k => module.gateway-common.gateway_params[k]
    if lookup(module.gateway-common.gateway_params, k, null) != null
  }
  test_params = {
    for k in local.hosts.kvm-1.guests :
    k => module.test-common.test_params[k]
    if lookup(module.test-common.test_params, k, null) != null
  }
  kvm_params        = {}
  services          = local.services
  renderer          = module.kvm-common.matchbox_rpc_endpoints.kvm-1
  kernel_image      = local.kernel_image
  initrd_images     = local.initrd_images
  kernel_params     = local.kernel_params
}

# Build and test environment
module "ignition-local" {
  source = "../modulesv2/ignition"

  controller_params = module.kubernetes-common.controller_params
  worker_params     = module.kubernetes-common.worker_params
  gateway_params    = module.gateway-common.gateway_params
  test_params       = module.test-common.test_params
  kvm_params        = module.kvm-common.kvm_params
  services          = local.services
  renderer          = local.local_renderer
  kernel_image      = local.kernel_image
  initrd_images     = local.initrd_images
  kernel_params     = local.kernel_params
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
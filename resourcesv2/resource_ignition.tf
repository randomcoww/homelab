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

  controller_templates = [
    "${path.module}/../templates/ignition/controller.ign.tmpl",
    "${path.module}/../templates/ignition/base.ign.tmpl",
    "${path.module}/../templates/ignition/containerd.ign.tmpl",
    "${path.module}/../templates/ignition/users.ign.tmpl",
  ]

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

  worker_templates = [
    "${path.module}/../templates/ignition/worker.ign.tmpl",
    "${path.module}/../templates/ignition/base.ign.tmpl",
    "${path.module}/../templates/ignition/storage.ign.tmpl",
    "${path.module}/../templates/ignition/containerd.ign.tmpl",
    "${path.module}/../templates/ignition/users.ign.tmpl",
  ]
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

  gateway_templates = [
    "${path.module}/../templates/ignition/gateway.ign.tmpl",
    "${path.module}/../templates/ignition/base.ign.tmpl",
    "${path.module}/../templates/ignition/containerd.ign.tmpl",
    "${path.module}/../templates/ignition/users.ign.tmpl",
  ]
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

  test_templates = [
    "${path.module}/../templates/ignition/test.ign.tmpl",
    "${path.module}/../templates/ignition/base.ign.tmpl",
    "${path.module}/../templates/ignition/storage.ign.tmpl",
    "${path.module}/../templates/ignition/containerd.ign.tmpl",
    "${path.module}/../templates/ignition/users.ign.tmpl",
  ]
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

  kvm_templates = [
    "${path.module}/../templates/ignition/kvm.ign.tmpl",
    "${path.module}/../templates/ignition/vlan-network.ign.tmpl",
    "${path.module}/../templates/ignition/base.ign.tmpl",
    "${path.module}/../templates/ignition/users.ign.tmpl",
  ]
}

module "desktop-common" {
  source = "../modulesv2/desktop_common"

  user                 = var.desktop_user
  password             = var.desktop_password
  timezone             = var.desktop_timezone
  internal_ca_cert_pem = tls_self_signed_cert.internal-ca.cert_pem
  mtu                  = local.mtu
  networks             = local.networks

  desktop_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "desktop")
  }

  desktop_templates = [
    "${path.module}/../templates/ignition/desktop.ign.tmpl",
    "${path.module}/../templates/ignition/base.ign.tmpl",
    "${path.module}/../templates/ignition/storage.ign.tmpl",
    "${path.module}/../templates/ignition/users.ign.tmpl",
  ]
}

##
## Write config to each matchbox host
## Hardcode each matchbox host until for_each module becomes available
##
module "ignition-kvm-0" {
  source = "../modulesv2/ignition"

  pxe_ignition_params = merge(
    # controller
    {
      for k in local.hosts.kvm-0.guests :
      k => module.kubernetes-common.controller_params[k]
      if lookup(module.kubernetes-common.controller_params, k, null) != null
    },
    # worker
    {
      for k in local.hosts.kvm-0.guests :
      k => module.kubernetes-common.worker_params[k]
      if lookup(module.kubernetes-common.worker_params, k, null) != null
    },
    # gateway
    {
      for k in local.hosts.kvm-0.guests :
      k => module.gateway-common.gateway_params[k]
      if lookup(module.gateway-common.gateway_params, k, null) != null
    },
    # test
    {
      for k in local.hosts.kvm-0.guests :
      k => module.test-common.test_params[k]
      if lookup(module.test-common.test_params, k, null) != null
    },
  )
  local_ignition_params = {}

  services      = local.services
  renderer      = module.kvm-common.matchbox_rpc_endpoints.kvm-0
  kernel_image  = local.kernel_image
  initrd_images = local.initrd_images
  kernel_params = local.kernel_params
}

module "ignition-kvm-1" {
  source = "../modulesv2/ignition"

  pxe_ignition_params = merge(
    # controller
    {
      for k in local.hosts.kvm-0.guests :
      k => module.kubernetes-common.controller_params[k]
      if lookup(module.kubernetes-common.controller_params, k, null) != null
    },
    # worker
    {
      for k in local.hosts.kvm-0.guests :
      k => module.kubernetes-common.worker_params[k]
      if lookup(module.kubernetes-common.worker_params, k, null) != null
    },
    # gateway
    {
      for k in local.hosts.kvm-0.guests :
      k => module.gateway-common.gateway_params[k]
      if lookup(module.gateway-common.gateway_params, k, null) != null
    },
    # test
    {
      for k in local.hosts.kvm-0.guests :
      k => module.test-common.test_params[k]
      if lookup(module.test-common.test_params, k, null) != null
    },
  )
  local_ignition_params = {}

  services      = local.services
  renderer      = module.kvm-common.matchbox_rpc_endpoints.kvm-1
  kernel_image  = local.kernel_image
  initrd_images = local.initrd_images
  kernel_params = local.kernel_params
}

# Build and test environment
module "ignition-local" {
  source = "../modulesv2/ignition"

  pxe_ignition_params = merge(
    # controller
    module.kubernetes-common.controller_params,
    # worker
    module.kubernetes-common.worker_params,
    # gateway
    module.gateway-common.gateway_params,
    # test
    module.test-common.test_params,
  )
  local_ignition_params = merge(
    # kvm
    module.kvm-common.kvm_params,
    # desktop
    module.desktop-common.desktop_params,
  )

  services      = local.services
  renderer      = local.local_renderer
  kernel_image  = local.kernel_image
  initrd_images = local.initrd_images
  kernel_params = local.kernel_params
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
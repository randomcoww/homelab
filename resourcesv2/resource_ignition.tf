
##
## Write config to each matchbox host
## Hardcode each matchbox host until for_each module becomes available
##
module "ignition-kvm-0" {
  source = "../modulesv2/ignition"

  pxe_ignition_params = {
    for h in local.hosts.kvm-0.guests :
    h => {
      templates = flatten([
        lookup(module.kubernetes-common.templates, h, []),
        lookup(module.gateway-common.templates, h, []),
        lookup(module.test-common.templates, h, []),
        lookup(module.ssh-common.templates, h, [])
      ])
      selector = lookup(local.host_network_by_type[h], "int", {})
    }
  }
  local_ignition_params = {}

  services      = local.services
  renderer      = module.kvm-common.matchbox_rpc_endpoints.kvm-0
  kernel_image  = local.kernel_image
  initrd_images = local.initrd_images
  kernel_params = local.kernel_params
}

module "ignition-kvm-1" {
  source = "../modulesv2/ignition"

  pxe_ignition_params = {
    for h in local.hosts.kvm-1.guests :
    h => {
      templates = flatten([
        lookup(module.kubernetes-common.templates, h, []),
        lookup(module.gateway-common.templates, h, []),
        lookup(module.test-common.templates, h, []),
        lookup(module.ssh-common.templates, h, [])
      ])
      selector = lookup(local.host_network_by_type[h], "int", {})
    }
  }
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

  pxe_ignition_params = {}
  local_ignition_params = {
    for h in keys(local.hosts) :
    h => {
      templates = flatten([
        lookup(module.kubernetes-common.templates, h, []),
        lookup(module.gateway-common.templates, h, []),
        lookup(module.test-common.templates, h, []),
        lookup(module.kvm-common.templates, h, []),
        lookup(module.desktop-common.templates, h, []),
        lookup(module.ssh-common.templates, h, [])
      ])
    }
  }

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
## PXE boot HW hosts
module "ignition-hw" {
  source = "../modules/ignition"

  services        = local.services
  ignition_params = local.pxeboot_hosts_by_local_rederer
  renderer        = module.template-ns.matchbox_rpc_endpoint
}
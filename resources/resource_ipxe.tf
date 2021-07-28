resource "null_resource" "tls_ipxe_client" {
  triggers = {
    cert_pem        = tls_locally_signed_cert.ipxe-client.cert_pem
    private_key_pem = tls_private_key.ipxe-client.private_key_pem
  }
}

## PXE boot HW hosts
module "ignition-ipxe" {
  source = "../modules/ignition"

  services        = local.services
  ignition_params = local.pxeboot_hosts_by_local_rederer
  renderer = {
    endpoint        = "${local.services.ipxe.vip}:${local.services.ipxe.ports.rpc}"
    cert_pem        = tls_locally_signed_cert.ipxe-client.cert_pem
    private_key_pem = tls_private_key.ipxe-client.private_key_pem
    ca_pem          = tls_self_signed_cert.ipxe-ca.cert_pem
  }
}
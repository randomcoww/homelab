# resource "vault_mount" "pki" {
#   type = "pki"
#   path = "pki"
# }
#
# resource "vault_auth_backend" "tls_auth_enable" {
#   type = "cert"
# }


## shuld run these manually
# vault mount pki
# vault secrets tune -max-lease-ttl=8760h pki
# vault auth enable cert

resource "tls_private_key" "serviceaccount" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}


module "pki_apiserver" {
  source = "../modules/vault"
  pki_path = "pki"
  role = "apiserver"
  csr_options = <<EOT
{
  "allow_any_name": true,
  "max_ttl": "8760h"
}
EOT
  # ca_cert_pem = "${tls_self_signed_cert.root.cert_pem}"
  ca_cert_pem = "${file("/etc/ssl/certs/internal-ca.pem")}"
  private_key_pem = "${replace(tls_private_key.serviceaccount.private_key_pem, "\n", "\\n")}"
}

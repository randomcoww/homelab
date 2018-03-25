module "pki_etcd" {
  source = "../modules/vault"
  pki_path = "k8s/pki/etcd"
  role = "member"
  csr_options = <<EOT
{
  "allow_any_name": true,
  "max_ttl": "720h"
}
EOT
}

module "pki_apiserver" {
  source = "../modules/vault"
  pki_path = "k8s/pki/apiserver"
  role = "apiserver"
  csr_options = <<EOT
{
  "allow_any_name": true,
  "max_ttl": "720h"
}
EOT
}

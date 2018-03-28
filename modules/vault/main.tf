## adapting https://blog.digitalocean.com/vault-and-kubernetes/ to terraform

# vault mount -path $CLUSTER_ID/pki/$COMPONENT pki
# vault mount-tune -max-lease-ttl=87600h $CLUSTER_ID/pki/etcd
# vault write $CLUSTER_ID/pki/$COMPONENT/root/generate/internal \
# common_name=$CLUSTER_ID/pki/$COMPONENT ttl=87600h

resource "vault_generic_secret" "ca" {
  path = "${var.pki_path}/root/generate/internal"
  disable_read = true
  data_json = <<EOT
{
  "common_name": "${var.pki_path}",
  "ttl": "8760h"
}
EOT
}

# servivce account

resource "vault_generic_secret" "private_key" {
  path = "secret/${var.role}"
  data_json = <<EOT
{
  "key": "${replace(var.private_key_pem, "\n", "\\n")}"
}
EOT
}

# vault write $CLUSTER_ID/pki/k8s/roles/kubelet \
#     allowed_domains="kubelet" \
#     allow_bare_domains=true \
#     allow_subdomains=false \
#     max_ttl="720h"

resource "vault_generic_secret" "role" {
  path = "${var.pki_path}/roles/${var.role}"
  data_json = "${var.csr_options}"
}

# cat <<EOT | vault policy-write $CLUSTER_ID/pki/etcd/member -
# path "$CLUSTER_ID/pki/etcd/issue/member" {
#   policy = "write"
# }
# EOT

resource "vault_policy" "policy" {
  name = "${var.pki_path}/${var.role}"

  policy = <<EOT
path "${var.pki_path}/issue/${var.role}" {
  policy = "write"
}

path "secret/${var.role}" {
  policy = "read"
}
EOT
}

# vault write auth/token/roles/k8s-$CLUSTER_ID \
# period="720h" \
# orphan=true \
# allowed_policies="$CLUSTER_ID/pki/etcd/member,$CLUSTER_ID/pki/k8s/kube-apiserver..."

resource "vault_generic_secret" "role_policy" {
  path = "auth/token/roles/${var.role}"
  # disable_read = true
  data_json = <<EOT
{
  "period": "8760h",
  "orphan": true,
  "allowed_policies": "${vault_policy.policy.name}"
}
EOT
}


## using TLS auth backend - enable cert
resource "vault_generic_secret" "tls_auth" {
  path = "auth/cert/certs/${var.role}"
  # disable_read = true
  data_json = <<EOT
{
  "display_name": "${var.role}",
  "policies": "${vault_policy.policy.name}",
  "certificate": "${replace(var.ca_cert_pem, "\n", "\\n")}"
}
EOT
}

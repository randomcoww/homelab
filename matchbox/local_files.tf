resource "local_file" "tls_ca" {
  content  = "${chomp(tls_self_signed_cert.root.cert_pem)}"
  filename = "output/ca.pem"
}

## matchbox
resource "local_file" "tls_key" {
  content  = "${chomp(tls_private_key.matchbox.private_key_pem)}"
  filename = "output/matchbox-key.pem"
}

resource "local_file" "tls_cert" {
  content  = "${chomp(tls_locally_signed_cert.matchbox.cert_pem)}"
  filename = "output/matchbox.pem"
}

## ssh ca
resource "local_file" "ssh_ca_key" {
  content  = "${chomp(tls_private_key.ssh_ca.private_key_pem)}"
  filename = "output/ssh-ca-key.pem"
}

## admin kubeconfig
resource "local_file" "kubeconfig" {
  content  = <<EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${replace(base64encode(chomp(tls_self_signed_cert.root.cert_pem)), "\n", "")}
    server: https://${var.controller_vip}:${var.apiserver_secure_port}
  name: ${var.cluster_name}
contexts:
- context:
    cluster: ${var.cluster_name}
    user: admin
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: admin
  user:
    as-user-extra: {}
    client-certificate-data: ${replace(base64encode(chomp(tls_locally_signed_cert.admin.cert_pem)), "\n", "")}
    client-key-data: ${replace(base64encode(chomp(tls_private_key.admin.private_key_pem)), "\n", "")}
EOF
  filename = "output/admin.kubeconfig"
}

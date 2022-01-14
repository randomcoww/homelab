## requires role bindings
## https://medium.com/@toddrosner/kubernetes-tls-bootstrapping-cf203776abc7
##
## example using certs instead of token auth file
#
# kubectl --kubeconfig=admin.kubeconfig create clusterrolebinding kubelet-bootstrap \
#   --clusterrole=system:node-bootstrapper \
#   --user=kubelet-bootstrap
#
# kubectl --kubeconfig=admin.kubeconfig create clusterrolebinding node-client-auto-approve-csr \
#   --clusterrole=system:certificates.k8s.io:certificatesigningrequests:nodeclient \
#   --group=system:node-bootstrapper
#
# kubectl --kubeconfig=admin.kubeconfig create clusterrolebinding node-client-auto-renew-crt \
#   --clusterrole=system:certificates.k8s.io:certificatesigningrequests:selfnodeclient \
#   --group=system:nodes

##
## matchbox
##
resource "tls_private_key" "bootstrap" {
  algorithm   = tls_private_key.kubernetes-ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "bootstrap" {
  key_algorithm   = tls_private_key.bootstrap.algorithm
  private_key_pem = tls_private_key.bootstrap.private_key_pem

  subject {
    common_name  = "kubelet-bootstrap"
    organization = "system:node-bootstrapper"
  }
}

resource "tls_locally_signed_cert" "bootstrap" {
  cert_request_pem   = tls_cert_request.bootstrap.cert_request_pem
  ca_key_algorithm   = tls_private_key.kubernetes-ca.algorithm
  ca_private_key_pem = tls_private_key.kubernetes-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.kubernetes-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
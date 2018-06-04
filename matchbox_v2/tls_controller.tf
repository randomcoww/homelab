##
## apiserver
##
resource "tls_cert_request" "kube_apiserver" {
  key_algorithm   = "${tls_private_key.kubernetes.algorithm}"
  private_key_pem = "${tls_private_key.kubernetes.private_key_pem}"

  subject {
    common_name  = "kubernetes"
    organization = "kubernetes"
  }

  dns_names = [
    "kubernetes.default",
    "host.internal",
    "svc.internal"
  ]

  ip_addresses = [
    "10.32.0.1",
    "127.0.0.1",
    "192.168.126.245"
  ]
}

resource "tls_locally_signed_cert" "kube_apiserver" {
  cert_request_pem   = "${tls_cert_request.kube_apiserver.cert_request_pem}"
  ca_key_algorithm   = "${tls_private_key.kubernetes.algorithm}"
  ca_private_key_pem = "${tls_private_key.kubernetes.private_key_pem}"
  ca_cert_pem        = "${tls_private_key.kubernetes.cert_pem}"
}

##
## controller-manager
##
resource "tls_cert_request" "kube_controller_manager" {
  key_algorithm   = "${tls_private_key.kubernetes.algorithm}"
  private_key_pem = "${tls_private_key.kubernetes.private_key_pem}"

  subject {
    common_name  = "system:kube-controller-manager"
    organization = "system:kube-controller-manager"
  }
}

resource "tls_locally_signed_cert" "kube_controller_manager" {
  cert_request_pem   = "${tls_cert_request.kube_controller_manager.cert_request_pem}"
  ca_key_algorithm   = "${tls_private_key.kubernetes.algorithm}"
  ca_private_key_pem = "${tls_private_key.kubernetes.private_key_pem}"
  ca_cert_pem        = "${tls_private_key.kubernetes.cert_pem}"
}

##
## scheduler
##
resource "tls_cert_request" "kube_scheduler" {
  key_algorithm   = "${tls_private_key.kubernetes.algorithm}"
  private_key_pem = "${tls_private_key.kubernetes.private_key_pem}"

  subject {
    common_name  = "system:kube-scheduler"
    organization = "system:kube-scheduler"
  }
}

resource "tls_locally_signed_cert" "kube_scheduler" {
  cert_request_pem   = "${tls_cert_request.kube_scheduler.cert_request_pem}"
  ca_key_algorithm   = "${tls_private_key.kubernetes.algorithm}"
  ca_private_key_pem = "${tls_private_key.kubernetes.private_key_pem}"
  ca_cert_pem        = "${tls_private_key.kubernetes.cert_pem}"
}

##
## proxy
##
resource "tls_cert_request" "kube_proxy" {
  key_algorithm   = "${tls_private_key.kubernetes.algorithm}"
  private_key_pem = "${tls_private_key.kubernetes.private_key_pem}"

  subject {
    common_name  = "system:kube-proxy"
    organization = "system:node-proxier"
  }
}

resource "tls_locally_signed_cert" "kube_proxy" {
  cert_request_pem   = "${tls_cert_request.kube_proxy.cert_request_pem}"
  ca_key_algorithm   = "${tls_private_key.kubernetes.algorithm}"
  ca_private_key_pem = "${tls_private_key.kubernetes.private_key_pem}"
  ca_cert_pem        = "${tls_private_key.kubernetes.cert_pem}"
}

##
## admin
##
resource "tls_cert_request" "admin" {
  key_algorithm   = "${tls_private_key.kubernetes.algorithm}"
  private_key_pem = "${tls_private_key.kubernetes.private_key_pem}"

  subject {
    common_name  = "admin"
    organization = "system:masters"
  }
}

resource "tls_locally_signed_cert" "admin" {
  cert_request_pem   = "${tls_cert_request.admin.cert_request_pem}"
  ca_key_algorithm   = "${tls_private_key.kubernetes.algorithm}"
  ca_private_key_pem = "${tls_private_key.kubernetes.private_key_pem}"
  ca_cert_pem        = "${tls_private_key.kubernetes.cert_pem}"
}

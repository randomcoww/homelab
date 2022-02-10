locals {
  ca = {
    algorithm       = tls_private_key.kubernetes-ca.algorithm
    private_key_pem = tls_private_key.kubernetes-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.kubernetes-ca.cert_pem
  }

  certs = {
    ca_cert = {
      content = tls_self_signed_cert.kubernetes-ca.cert_pem
    }
    ca_key = {
      content = tls_private_key.kubernetes-ca.private_key_pem
    }
    service_account_cert = {
      content = tls_private_key.service-account.public_key_pem
    }
    service_account_key = {
      content = tls_private_key.service-account.private_key_pem
    }
  }

  service_network = {
    prefix = "10.96.0.0/12"
    vips = {
      apiserver = "10.96.0.1"
      dns       = "10.96.0.10"
    }
  }
  pod_network = {
    prefix = "10.244.0.0/16"
  }

  cni_bridge_interface_name = "cni0"

  addons_resource_whitelist = [
    "core/v1/ConfigMap",
    "core/v1/Endpoints",
    "core/v1/Namespace",
    "core/v1/PersistentVolumeClaim",
    "core/v1/PersistentVolume",
    "core/v1/Pod",
    "core/v1/ReplicationController",
    "core/v1/Secret",
    "core/v1/Service",
    "batch/v1/Job",
    "batch/v1/CronJob",
    "apps/v1/DaemonSet",
    "apps/v1/Deployment",
    "apps/v1/ReplicaSet",
    "apps/v1/StatefulSet",
    "networking.k8s.io/v1/IngressClass",
    "networking.k8s.io/v1/NetworkPolicy",
    "apiextensions.k8s.io/v1/CustomResourceDefinition",
  ]
}

resource "random_string" "encryption-config-secret" {
  length  = 32
  special = false
}
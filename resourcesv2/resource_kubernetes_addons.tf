##
## minio user-pass
##
resource "random_password" "minio-user" {
  length  = 30
  special = false
}

resource "random_password" "minio-password" {
  length  = 30
  special = false
}

##
## grafana user-pass
##
resource "random_password" "grafana-user" {
  length  = 30
  special = false
}

resource "random_password" "grafana-password" {
  length  = 30
  special = false
}

module "kubernetes-addons" {
  source = "../modulesv2/kubernetes_addons"

  networks           = local.networks
  loadbalancer_pools = local.loadbalancer_pools
  services           = local.services
  domains            = local.domains
  container_images   = local.container_images

  secrets = {
    internal-tls = {
      namespace = "default"
      data = {
        "tls.crt" = tls_locally_signed_cert.internal.cert_pem
        "tls.key" = tls_private_key.internal.private_key_pem
      }
      type = "kubernetes.io/tls"
    },
    minio-auth = {
      namespace = "default"
      data = {
        access_key_id     = random_password.minio-user.result
        secret_access_key = random_password.minio-password.result
      },
      type = "Opaque"
    },
    grafana-auth = {
      namespace = "default"
      data = {
        user     = random_password.grafana-user.result
        password = random_password.grafana-password.result
      },
      type = "Opaque"
    }
  }

  # Render to one of KVM host matchbox instances
  # renderer = local.renderers[var.renderer]
  renderer = local.local_renderer
}
output "manifests" {
  value = concat([
    module.deployment.manifest,
    module.service.manifest,
    module.httproute.manifest,
    module.secret.manifest,
    ], [
    for _, m in [
      # database
      {
        apiVersion = "postgresql.cnpg.io/v1"
        kind       = "Cluster"
        metadata = {
          name      = "${var.name}-pg"
          namespace = var.namespace
        }
        spec = {
          instances = 3
          storage = {
            size = "2Gi"
          }
          bootstrap = {
            initdb = {
              database = "lldap"
              owner    = "lldap"
            }
          }
          resources = {
            requests = {
              memory = "256Mi"
            }
          }
        }
      },

      # server cert
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${var.name}-tls"
          isCA       = false
          privateKey = {
            algorithm = "RSA"
            size      = 4096
          }
          commonName = var.name
          usages = [
            "key encipherment",
            "digital signature",
            "server auth",
          ]
          ipAddresses = [
            "127.0.0.1",
          ]
          dnsNames = [
            var.name,
            var.service_hostname,
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },
    ] :
    yamlencode(m)
  ])
}
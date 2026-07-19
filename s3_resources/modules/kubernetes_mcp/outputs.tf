output "manifests" {
  value = concat([
    module.deployment.manifest,
    module.service.manifest,
    ], [
    for _, m in [
      {
        apiVersion = "v1"
        kind       = "ServiceAccount"
        metadata = {
          name      = var.name
          namespace = var.namespace
          labels = {
            app     = var.name
            release = var.release
          }
        }
      },
      {
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind       = "ClusterRole"
        metadata = {
          name = var.name
        }
        rules = [
          {
            apiGroups = ["*"]
            resources = ["*"]
            verbs     = ["get", "list", "watch"]
          },
        ]
      },
      {
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind       = "ClusterRoleBinding"
        metadata = {
          name = var.name
          labels = {
            app     = var.name
            release = var.release
          }
        }
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io"
          kind     = "ClusterRole"
          name     = var.name
        }
        subjects = [
          {
            kind      = "ServiceAccount"
            name      = var.name
            namespace = var.namespace
          },
        ]
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
            algorithm = "ECDSA"
            size      = 521
          }
          commonName = var.name
          usages = [
            "key encipherment",
            "digital signature",
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
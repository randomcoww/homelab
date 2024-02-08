output "manifest" {
  value = yamlencode({
    kind       = "Config"
    apiVersion = "v1"
    clusters = [
      {
        cluster = {
          certificate-authority-data = replace(base64encode(chomp(var.ca_cert_pem)), "\n", "")
          server                     = var.apiserver_endpoint
        }
        name = var.cluster_name
      },
    ]
    contexts = [
      {
        context = {
          cluster = var.cluster_name
          user    = var.user
        }
        name = var.context
      },
    ]
    current-context = var.context
    users = [
      {
        name = var.user
        user = {
          client-certificate-data = replace(base64encode(chomp(var.client_cert_pem)), "\n", "")
          client-key-data         = replace(base64encode(chomp(var.client_key_pem)), "\n", "")
        }
      },
    ]
  })
  sensitive = true
}
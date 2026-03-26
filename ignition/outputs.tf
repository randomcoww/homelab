output "ignition" {
  value = {
    for host_key, content in data.ct_config.ignition :
    host_key => content.rendered
  }
  sensitive = true
}

output "podlist" {
  value = {
    for host_key in keys(local.hosts) :
    host_key => yamlencode({
      apiVersion = "v1"
      kind       = "PodList"
      items = flatten([
        for _, m in local.modules_enabled :
        [
          for pod in try(m[host_key].pod_manifests, []) :
          yamldecode(pod)
        ]
      ])
    })
  }
  sensitive = true
}

output "kubernetes_ca" {
  value = {
    algorithm       = tls_private_key.kubernetes-ca.algorithm
    private_key_pem = tls_private_key.kubernetes-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.kubernetes-ca.cert_pem
  }
  sensitive = true
}

output "ssh_ca" {
  value = {
    algorithm          = tls_private_key.ssh-ca.algorithm
    private_key_pem    = tls_private_key.ssh-ca.private_key_pem
    public_key_openssh = tls_private_key.ssh-ca.public_key_openssh
  }
  sensitive = true
}

output "internal_ca" {
  value = {
    algorithm       = tls_private_key.trusted-ca.algorithm
    private_key_pem = tls_private_key.trusted-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.trusted-ca.cert_pem
  }
  sensitive = true
}
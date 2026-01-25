output "ssh_user_cert_authorized_key" {
  value = ssh_user_cert.ssh-client.cert_authorized_key
}

output "kubernetes_admin" {
  value = {
    algorithm       = tls_private_key.kubernetes-admin.algorithm
    private_key_pem = tls_private_key.kubernetes-admin.private_key_pem
    cert_pem        = tls_locally_signed_cert.kubernetes-admin.cert_pem
    ca_cert_pem     = data.terraform_remote_state.sr.outputs.kubernetes.ca.cert_pem
  }
  sensitive = true
}

output "internal_ca" {
  value = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
}

output "kubeconfig" {
  value     = module.admin-kubeconfig.manifest
  sensitive = true
}

output "kubeconfig_cluster" {
  value     = module.admin-kubeconfig-cluster.manifest
  sensitive = true
}

output "mc_config" {
  value = {
    version = "10"
    aliases = {
      m = {
        url       = "https://${local.services.minio.ip}:${local.service_ports.minio}"
        accessKey = data.terraform_remote_state.sr.outputs.minio.access_key_id
        secretKey = data.terraform_remote_state.sr.outputs.minio.secret_access_key
        api       = "S3v4"
        path      = "auto"
      }
    }
  }
  sensitive = true
}

output "rclone_config" {
  value     = <<-EOF
[m]
type = s3
provider = Minio
access_key_id = ${data.terraform_remote_state.sr.outputs.minio.access_key_id}
secret_access_key = ${data.terraform_remote_state.sr.outputs.minio.secret_access_key}
region = auto
endpoint = https://${local.services.minio.ip}:${local.service_ports.minio}
%{~for name, res in data.terraform_remote_state.sr.outputs.r2_bucket~}


[cf-${name}]
type = s3
provider = Cloudflare
access_key_id = ${res.access_key_id}
secret_access_key = ${res.secret_access_key}
region = auto
endpoint = https://${res.url}
%{~endfor~}
EOF
  sensitive = true
}
output "ssh_user_cert_authorized_key" {
  value = ssh_user_cert.ssh-client.cert_authorized_key
}

output "internal_ca" {
  value = {
    cert_pem = data.terraform_remote_state.host.outputs.internal_ca.cert_pem
  }
}

output "registry_client" {
  value = {
    private_key_pem = tls_private_key.registry-client.private_key_pem
    cert_pem        = tls_locally_signed_cert.registry-client.cert_pem
  }
  sensitive = true
}

output "kubeconfig" {
  value     = module.kubeconfig.manifest
  sensitive = true
}

output "mc_config" {
  value = jsonencode({
    version = "10"
    aliases = {
      m = {
        url       = "https://${local.services.minio.ip}:${local.service_ports.minio}"
        accessKey = data.terraform_remote_state.host.outputs.minio.access_key_id
        secretKey = data.terraform_remote_state.host.outputs.minio.secret_access_key
        api       = "S3v4"
        path      = "auto"
      }
    }
  })
  sensitive = true
}

output "rclone_config" {
  value     = <<EOF
[m]
type = s3
provider = Minio
access_key_id = ${data.terraform_remote_state.host.outputs.minio.access_key_id}
secret_access_key = ${data.terraform_remote_state.host.outputs.minio.secret_access_key}
region = auto
endpoint = https://${local.services.minio.ip}:${local.service_ports.minio}

%{~for name, res in data.terraform_remote_state.sr.outputs.r2_bucket}
[cf-${name}]
type = s3
provider = Cloudflare
access_key_id = ${res.access_key_id}
secret_access_key = ${res.secret_access_key}
region = auto
endpoint = https://${res.url}
%{endfor~}
EOF
  sensitive = true
}
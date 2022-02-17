output "ca" {
  value = local.ca
}

output "certs" {
  value = local.certs
}

output "encryption_config_secret" {
  value = base64encode(chomp(random_string.encryption-config-secret.result))
}
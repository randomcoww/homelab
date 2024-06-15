output "statefulset" {
  value = module.statefulset.manifest
}

output "secret" {
  value = module.secret.manifest
}

output "name" {
  value = var.name
}
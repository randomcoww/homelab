output "statefulset" {
  value = module.statefulset.statefulset
}

output "secret" {
  value = module.statefulset.secret
}

output "name" {
  value = var.name
}
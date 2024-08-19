output "statefulset" {
  value = module.statefulset-litestream.statefulset
}

output "secret" {
  value = module.statefulset-litestream.secret
}

output "name" {
  value = var.name
}
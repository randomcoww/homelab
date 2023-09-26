resource "random_password" "authelia-storage-secret" {
  length  = 64
  special = false
}
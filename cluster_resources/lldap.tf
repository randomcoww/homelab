resource "random_password" "lldap-storage-secret" {
  length  = 64
  special = false
}
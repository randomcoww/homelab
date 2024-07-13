resource "random_password" "lldap-storage-secret" {
  length  = 128
  special = false
}

resource "random_password" "lldap-jwt-token" {
  length  = 128
  special = true
}

resource "random_password" "lldap-user" {
  length  = 64
  special = false
}

resource "random_password" "lldap-password" {
  length  = 64
  special = false
}
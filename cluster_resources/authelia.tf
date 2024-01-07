resource "random_password" "authelia-storage-secret" {
  length  = 64
  special = false
}

resource "random_password" "authelia-session-encryption-key" {
  length  = 128
  special = false
}

resource "random_password" "authelia-jwt-token" {
  length  = 128
  special = false
}
resource "random_password" "luks-key" {
  for_each = var.hosts

  length  = 512
  special = false
}
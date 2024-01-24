resource "random_id" "private-key" {
  byte_length = 32
}

resource "random_id" "noise-private-key" {
  byte_length = 32
}
locals {
  ids = [
    for i in range(var.replica_count) :
    format("%X", var.bssid_base + i)
  ]
}
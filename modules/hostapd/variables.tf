variable "template_params" {
  type = any
}

variable "ht_capab" {
  type = list(string)
  default = [
    "LDPC",
    "HT40-",
    "HT40+",
    "SHORT-GI-20",
    "SHORT-GI-40",
    "TX-STBC",
    "RX-STBC1",
    "DSSS_CCK-40",
  ]
}
output "templates" {
  value = {
    for host, params in var.hosts :
    host => [
      for template in var.templates :
      templatefile(template, {
        wireguard_if     = "wg0"
        wireguard_config = var.wireguard_config
      })
    ]
  }
}
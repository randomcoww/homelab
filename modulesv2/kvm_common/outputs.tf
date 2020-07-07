output "templates" {
  value = {
    for host, params in var.hosts :
    host => [
      for template in var.templates :
      templatefile(template, {
        p    = params
        user = var.user
      })
    ]
  }
}
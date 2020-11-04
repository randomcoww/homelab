output "kubernetes" {
  value = flatten([
    for f in fileset(".", "${path.module}/templates/kubernetes/*") : concat([
      for k, v in var.secrets :
      templatefile(f, {
        name      = v.name
        namespace = v.namespace
        data      = v.data
        type      = "Opaque"
      })
    ])
  ])
}
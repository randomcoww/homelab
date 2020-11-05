output "kubernetes" {
  value = flatten([
    for f in fileset(".", "${path.module}/templates/kubernetes/*") :
    [
      for v in var.secrets :
      templatefile(f, {
        namespace = v.namespace
        name      = v.name
        type      = "Opaque"
        data      = v.data
      })
    ]
  ])
}
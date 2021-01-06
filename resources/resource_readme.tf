##
## Render README
##
resource "local_file" "readme" {
  content = templatefile("./templates/README.md", {
    secrets_file     = "secrets.tfvars"
    container_images = local.container_images
    hypervisor_hosts = {
      for k in local.components.hypervisor.nodes :
      k => local.aggr_hosts[k]
    }
  })
  filename = "../README.md"
}
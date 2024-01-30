locals {
  ignition_snippets = [
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version      = var.ignition_version
      ssm_access_key_id     = var.ssm_access_key_id
      ssm_secret_access_key = var.ssm_secret_access_key
      ssm_resource          = var.ssm_resource
      ssm_region            = var.ssm_region
    })
  ]
}
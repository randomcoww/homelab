output "rendered" {
  value = {
    for k in keys(var.ignition_params) :
    k => data.ct_config.ign[k].rendered
  }
}
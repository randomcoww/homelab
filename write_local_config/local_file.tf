resource "local_sensitive_file" "config" {
  for_each = {
    for _, f in data.terraform_remote_state.ignition.outputs.remote_files[var.host_key] :
    f.path => f
  }

  content         = each.value.contents
  file_permission = lookup(each.value, "mode", "0600")
  filename        = each.key
}
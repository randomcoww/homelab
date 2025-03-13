resource "local_sensitive_file" "config" {
  for_each = {
    for _, f in data.terraform_remote_state.ignition.outputs.remote_files[var.hostname] :
    f.path => f
  }

  content         = each.value.contents
  file_permission = format("%04o", lookup(each.value, "mode", 384))
  filename        = each.key
}
module "write-sentinel-file" {
  for_each = data.terraform_remote_state.bucket-ops.outputs.netboot-host-digest

  source   = "../modules/remote_exec"
  host     = each.key
  ssh_user = "fcos"
  command = [
    "echo -n '${each.value}' | sudo tee /var/run/reboot-required",
  ]
  triggers_replace = [
    timestamp(),
  ]
}
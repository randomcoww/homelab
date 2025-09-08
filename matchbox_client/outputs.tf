output "config" {
  value = {
    for key, boot in matchbox_profile.ignition :
    key => [
      sha256(boot.kernel),
      sha256(join(" ", boot.initrd)),
      sha256(join(" ", sort(boot.args))),
      sha256(boot.raw_ignition),
    ]
  }
}
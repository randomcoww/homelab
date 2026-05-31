output "manifests" {
  value = [
    module.daemonset.manifest,
  ]
}
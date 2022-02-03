locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      minio_container_image    = var.minio_container_image
      minio_port               = var.minio_port
      minio_console_port       = var.minio_console_port
      volume_paths             = var.volume_paths
      static_pod_manifest_path = var.static_pod_manifest_path
      minio_credentials        = var.minio_credentials
    })
  ]
}
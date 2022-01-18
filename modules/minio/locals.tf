locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      minio_container_image    = var.minio_container_image
      minio_port               = var.minio_port
      volume_paths             = var.volume_paths
      static_pod_manifest_path = var.static_pod_manifest_path
      minio_user               = random_password.minio-user.result
      minio_password           = random_password.minio-password.result
    })
  ]
}
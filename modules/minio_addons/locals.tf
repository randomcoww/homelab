locals {
  addon_manifests = {
    for f in fileset(".", "${path.module}/manifests/*.yaml") :
    basename(f) => templatefile(f, {
      resource_name       = var.resource_name
      namespace           = var.resource_namespace
      replica_count       = var.replica_count
      minio_ip            = var.minio_ip
      minio_port          = var.minio_port
      minio_console_port  = var.minio_console_port
      affinity_host_class = var.affinity_host_class
      volume_paths        = var.volume_paths
      access_key_id       = random_password.minio-access-key-id.result
      secret_access_key   = random_password.minio-secret-access-key.result
      container_images    = var.container_images
    })
  }
}
module "fuse-device-plugin" {
  source    = "./modules/fuse_device_plugin"
  name      = "fuse-device-plugin"
  namespace = "kube-system"
  release   = "0.1.1"
  images = {
    fuse_device_plugin = local.container_images.fuse_device_plugin
  }
  kubelet_root_path = local.kubernetes.kubelet_root_path
}

module "nvidia-driver" {
  source    = "./modules/nvidia_driver"
  name      = "nvidia-driver"
  namespace = "kube-system"
  release   = "0.1.1"
  images = {
    nvidia_driver = local.container_images.nvidia_driver
  }
}

resource "minio_s3_bucket" "data" {
  for_each = local.minio_data_buckets

  bucket        = each.value.name
  acl           = lookup(each.value, "acl", "private")
  force_destroy = false
}
provider "helm" {
  kubernetes {
    config_path = "output/kubeconfig/${local.kubernetes.cluster_name}.kubeconfig"
  }
}

provider "aws" {
  region = var.aws_region
}
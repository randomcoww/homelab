data "terraform_remote_state" "ignition" {
  backend = "s3"
  config = {
    bucket = "randomcoww-tfstate"
    key    = "ignition_config-23.tfstate"
    region = "us-west-2"
  }
}

module "kubernetes-client" {
  source = "./modules/kubernetes_admin"

  cluster_name       = data.terraform_remote_state.ignition.outputs.kubernetes.cluster_name
  ca                 = data.terraform_remote_state.ignition.outputs.kubernetes.ca
  apiserver_endpoint = data.terraform_remote_state.ignition.outputs.kubernetes.apiserver_endpoint
}

module "ssh-client" {
  source = "./modules/ssh_client"

  key_id                = var.ssh_client.key_id
  public_key_openssh    = var.ssh_client.public_key
  early_renewal_hours   = var.ssh_client.early_renewal_hours
  validity_period_hours = var.ssh_client.validity_period_hours
  ca                    = data.terraform_remote_state.ignition.outputs.ssh_ca
}

# Outputs

output "ssh_user_cert_authorized_key" {
  value = module.ssh-client.ssh_user_cert_authorized_key
}

output "kubeconfig" {
  value = nonsensitive(module.kubernetes-client.kubeconfig)
}


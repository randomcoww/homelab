data "terraform_remote_state" "matchbox-client" {
  backend = "local"
  config = {
    path = "../matchbox_client/terraform.tfstate"
  }
}
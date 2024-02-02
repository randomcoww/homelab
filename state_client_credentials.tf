data "terraform_remote_state" "client" {
  backend = "local"
  config = {
    path = "../client_credentials/terraform.tfstate"
  }
}
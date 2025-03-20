data "terraform_remote_state" "bootstrap-server" {
  backend = "local"
  config = {
    path = "../bootstrap_server/terraform.tfstate"
  }
}
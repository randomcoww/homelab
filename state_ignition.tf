data "terraform_remote_state" "ignition" {
  backend = "local"
  config = {
    path = "../ignition/terraform.tfstate"
  }
}
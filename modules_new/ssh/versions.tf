terraform {
  required_providers {
    ssh = {
      source = "github.com/randomcoww/ssh"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
  required_version = ">= 1.0"
}

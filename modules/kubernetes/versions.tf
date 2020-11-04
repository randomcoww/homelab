terraform {
  required_version = ">= 0.13"
  required_providers {
    kubernetes-alpha = {
      source = "github.com/hashicorp/kubernetes-alpha"
    }
  }
}

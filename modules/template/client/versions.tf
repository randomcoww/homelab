terraform {
  required_providers {
    http = {
      source = "hashicorp/http"
    }
    syncthing = {
      source = "github.com/randomcoww/syncthing"
    }
  }
  required_version = ">= 0.13"
}
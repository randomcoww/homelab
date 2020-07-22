terraform {
  required_providers {
    ct = {
      source = "github.com/poseidon/ct"
    }
    matchbox = {
      source = "github.com/poseidon/matchbox"
    }
  }
  required_version = ">= 0.13"
}

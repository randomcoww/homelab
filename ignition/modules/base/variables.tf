variable "butane_version" {
  type = string
}

variable "hostname" {
  type = string
}

variable "terraform_backend_bucket" {
  type = object({
    url               = string
    bucket            = string
    access_key_id     = string
    secret_access_key = string
  })
}

variable "terraform_git_repo" {
  type    = string
  default = "https://github.com/randomcoww/homelab.git"
}

variable "images" {
  type = object({
    terraform = string
  })
}
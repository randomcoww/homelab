# User override (local.preprocess.users)
variable "users" {
  type    = any
  default = {}
}

variable "aws_region" {
  type    = string
  default = "us-west-2"
}
variable "user" {
  type = string
}

variable "desktop_user" {
  type = string
}

variable "desktop_uid" {
  type = number
}

variable "desktop_password" {
  type = string
}

variable "domains" {
  type = map(string)
}

variable "hosts" {
  type = any
}

variable "templates" {
  type = list(string)
}
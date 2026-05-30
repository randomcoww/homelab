variable "github_username" {
  type = string
}

variable "github_token" {
  type = string
}

variable "smtp_host" {
  type = string
}

variable "smtp_port" {
  type    = number
  default = 587
}

variable "smtp_username" {
  type = string
}

variable "smtp_password" {
  type = string
}

variable "scrape_proxy_server" {
  type = string
}

variable "scrape_proxy_username" {
  type = string
}

variable "scrape_proxy_password" {
  type = string
}
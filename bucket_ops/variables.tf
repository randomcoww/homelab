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

variable "slack_bot_token" {
  type = string
}

variable "slack_app_token" {
  type = string
}

variable "slack_allowed_users" {
  type = string
}

variable "slack_home_channel" {
  type = string
}

variable "alpaca_api_key" {
  type = string
}

variable "alpaca_secret_key" {
  type = string
}
variable "github" {
  type = object({
    username = string
    token    = string
  })
}

variable "smtp" {
  type = object({
    host     = string
    port     = number
    username = string
    password = string
  })
}

variable "scrape_proxy" {
  type = object({
    server   = string
    username = string
    password = string
  })
}
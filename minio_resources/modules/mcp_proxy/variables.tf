variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type    = string
  default = "0.1.0"
}

variable "replicas" {
  type = number
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    mcp_proxy       = string
    prometheus_mcp  = string
    kubernetes_mcp  = string
    searxng_mcp     = string
    camofox_mcp     = string
    camofox_browser = string
  })
}

variable "scrape_proxy" {
  type = object({
    server   = string
    username = string
    password = string
  })
}

variable "auth_token" {
  type = string
}

variable "prometheus_endpoint" {
  type = string
}

variable "searxng_endpoint" {
  type = string
}

variable "ingress_hostname" {
  type = string
}

variable "gateway_ref" {
  type = any
}
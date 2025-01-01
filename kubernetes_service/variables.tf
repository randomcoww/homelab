variable "smtp" {
  type = object({
    host     = string
    port     = string
    username = string
    password = string
  })
}
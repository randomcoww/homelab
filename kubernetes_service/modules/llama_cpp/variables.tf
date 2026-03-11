variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type = string
}

variable "llama_swap_config" {
  type    = any
  default = {}
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    llama_swap       = string
    jina_reranker_v3 = string
    qwen3_embedding  = string
    glm_4_7_flash    = string
    gpt_oss_120b     = string
  })
}

variable "api_keys" {
  type    = list(string)
  default = []
}

variable "extra_envs" {
  type = list(object({
    name  = string
    value = any
  }))
  default = []
}

variable "ingress_hostname" {
  type = string
}

variable "gateway_ref" {
  type = any
}
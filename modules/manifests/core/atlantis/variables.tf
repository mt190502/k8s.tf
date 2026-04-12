## ============================================================================================= ##
#  modules/manifests/core/atlantis/variables.tf                                                   #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable Atlantis deployment"
  type        = bool
  default     = false
}

variable "config" {
  description = "Atlantis configuration"
  type = object({
    aws_s3_region     = optional(string, "us-east-1")
    basic_auth        = optional(bool, false)
    domain            = string
    gateway_name      = optional(string)
    gateway_namespace = optional(string)
    github_app_slug   = optional(string)
    hostname          = string
    image_tag         = optional(string, "v0.41.0")
    name              = optional(string, "atlantis")
    port              = optional(number, 80)
    preferred_gateway = optional(string, "cilium")
    repo_allowlist    = string
  })
}

variable "secrets" {
  description = "Atlantis secrets"
  type        = map(map(string))
  sensitive   = true
  default     = {}
}
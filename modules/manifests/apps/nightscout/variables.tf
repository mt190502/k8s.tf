## ============================================================================================= ##
#  modules/manifests/apps/nightscout/variables.tf                                                 #
#                                                                                                 #
#    enabled             --- Enable this module                                                   #
#    config              --- Configuration object                                                 #
#      replicas          --- Configure desired replica count                                      #
#      env               --- Environment variables for Nightscout                                 #
#      gateway_name      --- Gateway name (from cert-manager)                                     #
#      gateway_namespace --- Gateway namespace (from cert-manager)                                #
#      domain            --- Base domain for HTTPRoute hostname                                   #
#    image_version       --- Nightscout image version                                             #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Nightscout configuration"
  type = object({
    replicas          = optional(number)
    env               = optional(map(string))
    gateway_name      = optional(string)
    gateway_namespace = optional(string)
    domain            = optional(string)
  })
  default = {
    replicas = 1
    env      = {}
  }
}

variable "secrets" {
  description = "Nightscout secrets"
  type = object({
    api_secret = string
  })
  sensitive = true
}

variable "image_version" {
  description = "Nightscout image version"
  type        = string
  default     = ""
}